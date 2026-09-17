#import <CoreImage/CoreImage.h>
#import "Core/SGCore.h"
#import "SGRPalette.h"
#import "SGRTokens.h"

static const size_t kSample = 64;      // the artwork shrunk to this square before its colours are read
static const size_t kEdgeRows = 10;    // the bottom rows of it averaged into the edge colour
static const CGFloat kMaxSaturation = 0.55;
static const CGFloat kMaxLuminance = 0.07, kMaxLuminanceContrast = 0.04;
static const CGFloat kBackdropWidth = 160, kBackdropMaxHeight = 400, kBackdropSigma = 12;
static const CGFloat kDissolveWidth = 96, kDissolveSigma = 5;
static const CGFloat kFadeFrom = 0.55, kDissolveOpaque = 0.85;

@interface SGRPalette ()
@property (nonatomic, readwrite) UIColor *edgeColor;
@property (nonatomic, readwrite) UIColor *fieldColor;
@property (nonatomic, readwrite) UIImage *backdrop;
@property (nonatomic, readwrite) UIImage *dissolve;
@end

static dispatch_queue_t paletteQueue(void) {
    static dispatch_queue_t queue;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        queue = dispatch_queue_create("spotifyglass.redesign.palette", dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INITIATED, 0));
    });
    return queue;
}

static CGColorSpaceRef sRGB(void) {
    static CGColorSpaceRef space;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ space = CGColorSpaceCreateWithName(kCGColorSpaceSRGB); });
    return space;
}

// One context for the whole launch; CIContext is safe to share and costly to make.
static CIContext *blurContext(void) {
    static CIContext *context;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        context = [CIContext contextWithOptions:@{kCIContextCacheIntermediates: @NO, kCIContextWorkingColorSpace: (__bridge id)sRGB()}];
    });
    return context;
}

static CGContextRef newBitmap(size_t width, size_t height) {
    return CGBitmapContextCreate(NULL, width, height, 8, width * 4, sRGB(), (CGBitmapInfo)kCGImageAlphaPremultipliedLast);
}

static void drawFilling(CGContextRef context, CGImageRef image, size_t width, size_t height) {
    CGFloat iw = CGImageGetWidth(image), ih = CGImageGetHeight(image);
    CGFloat scale = MAX(width / iw, height / ih);
    CGContextSetInterpolationQuality(context, kCGInterpolationMedium);
    CGContextDrawImage(context, CGRectMake((width - iw * scale) / 2, (height - ih * scale) / 2, iw * scale, ih * scale), image);
}

#pragma mark - colour

static CGFloat toLinear(CGFloat c) {
    return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4);
}

static CGFloat toEncoded(CGFloat c) {
    return c <= 0.0031308 ? c * 12.92 : 1.055 * pow(c, 1 / 2.4) - 0.055;
}

static UIColor *fieldColorFor(UIColor *color, CGFloat ceiling) {
    CGFloat r = 0, g = 0, b = 0, a = 1, h = 0, s = 0, v = 0;
    if (![color getRed:&r green:&g blue:&b alpha:&a]) {
        CGFloat white = 0;
        if (![color getWhite:&white alpha:&a]) return SGRNeutralField();
        r = g = b = white;
    }
    UIColor *clamped = [UIColor colorWithRed:MIN(1, MAX(0, r)) green:MIN(1, MAX(0, g)) blue:MIN(1, MAX(0, b)) alpha:1];
    [clamped getHue:&h saturation:&s brightness:&v alpha:&a];
    [[UIColor colorWithHue:h saturation:MIN(s, kMaxSaturation) brightness:v alpha:1] getRed:&r green:&g blue:&b alpha:&a];
    CGFloat lr = toLinear(r), lg = toLinear(g), lb = toLinear(b);
    CGFloat luminance = 0.2126 * lr + 0.7152 * lg + 0.0722 * lb;
    if (luminance > ceiling) {
        CGFloat k = ceiling / luminance;
        lr *= k, lg *= k, lb *= k;
    }
    return [UIColor colorWithRed:toEncoded(lr) green:toEncoded(lg) blue:toEncoded(lb) alpha:1];
}

UIColor *SGRFieldColorFor(UIColor *color) {
    return color ? fieldColorFor(color, SGRIncreaseContrast() ? kMaxLuminanceContrast : kMaxLuminance) : SGRNeutralField();
}

// The artwork squeezed into a small square, whatever its aspect, and the bottom rows of that averaged
// by coverage. A bitmap context keeps its rows top to bottom, so the last rows are the bottom edge.
static UIColor *edgeColorOf(CGImageRef image) {
    CGContextRef context = newBitmap(kSample, kSample);
    if (!context) return nil;
    CGContextSetInterpolationQuality(context, kCGInterpolationMedium);
    CGContextDrawImage(context, CGRectMake(0, 0, kSample, kSample), image);
    const uint8_t *px = CGBitmapContextGetData(context);
    double r = 0, g = 0, b = 0, coverage = 0;
    for (size_t y = kSample - kEdgeRows; px && y < kSample; y++) {
        for (size_t x = 0; x < kSample; x++) {
            const uint8_t *p = px + (y * kSample + x) * 4;
            r += p[0], g += p[1], b += p[2], coverage += p[3];
        }
    }
    CGContextRelease(context);
    // Premultiplied, so the sums over the summed alpha are the average of what is actually there.
    if (coverage < 1) return nil;
    return [UIColor colorWithRed:r / coverage green:g / coverage blue:b / coverage alpha:1];
}

#pragma mark - bitmaps

// The artwork drawn to fill the size, then blurred with its edges clamped so the border does not
// darken. Returned retained.
static CGImageRef newBlurred(CGImageRef image, size_t width, size_t height, CGFloat sigma) {
    CGContextRef context = newBitmap(width, height);
    if (!context) return NULL;
    drawFilling(context, image, width, height);
    CGImageRef small = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    if (!small) return NULL;
    CIImage *input = [CIImage imageWithCGImage:small];
    CGImageRelease(small);
    CIImage *output = [[input imageByClampingToExtent] imageByApplyingGaussianBlurWithSigma:sigma];
    return [blurContext() createCGImage:output fromRect:input.extent format:kCIFormatRGBA8 colorSpace:sRGB()];
}

// A black gradient from `a0` at `y0` to `a1` at `y1` (shares of the height, top down), extended
// past both ends; with kCGBlendModeDestinationIn it becomes an alpha ramp instead of a dim.
static void drawRamp(CGContextRef context, size_t height, CGFloat y0, CGFloat a0, CGFloat y1, CGFloat a1, CGBlendMode mode) {
    CGFloat components[] = {0, 0, 0, a0, 0, 0, 0, a1};
    CGFloat locations[] = {0, 1};
    CGGradientRef gradient = CGGradientCreateWithColorComponents(sRGB(), components, locations, 2);
    CGContextSetBlendMode(context, mode);
    CGContextDrawLinearGradient(context, gradient, CGPointMake(0, y0 * height), CGPointMake(0, y1 * height),
                                kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
    CGGradientRelease(gradient);
}

static UIImage *finished(CGImageRef blurred, BOOL dim, CGFloat dimBottom, CGFloat rampFrom, CGFloat alphaFrom, CGFloat rampTo, CGFloat alphaTo) {
    size_t width = CGImageGetWidth(blurred), height = CGImageGetHeight(blurred);
    CGContextRef context = newBitmap(width, height);
    if (!context) return nil;
    CGContextDrawImage(context, CGRectMake(0, 0, width, height), blurred);
    // Top down from here on.
    CGContextTranslateCTM(context, 0, height);
    CGContextScaleCTM(context, 1, -1);
    if (dim) drawRamp(context, height, 0, 0.25, kFadeFrom, dimBottom, kCGBlendModeNormal);
    drawRamp(context, height, rampFrom, alphaFrom, rampTo, alphaTo, kCGBlendModeDestinationIn);
    CGImageRef result = CGBitmapContextCreateImage(context);
    CGContextRelease(context);
    UIImage *image = result ? [UIImage imageWithCGImage:result scale:1 orientation:UIImageOrientationUp] : nil;
    CGImageRelease(result);
    return image;
}

@implementation SGRPalette

+ (void)paletteForImage:(UIImage *)image request:(SGRPaletteRequest)request completion:(void (^)(SGRPalette *palette))completion {
    if (!completion) return;
    CGFloat ceiling = SGRIncreaseContrast() ? kMaxLuminanceContrast : kMaxLuminance;
    dispatch_async(paletteQueue(), ^{
        SGRPalette *palette = nil;
        CGImageRef cg = image.CGImage;
        UIColor *edge = cg && CGImageGetWidth(cg) && CGImageGetHeight(cg) ? edgeColorOf(cg) : nil;
        if (edge) {
            CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
            palette = [SGRPalette new];
            palette.edgeColor = edge;
            palette.fieldColor = fieldColorFor(edge, ceiling);
            CGSize area = request.backdropSize;
            if (area.width > 0 && area.height > 0) {
                size_t width = (size_t)kBackdropWidth, height = (size_t)MIN(kBackdropMaxHeight, round(kBackdropWidth * area.height / area.width));
                CGImageRef blurred = newBlurred(cg, width, MAX(height, 1), kBackdropSigma);
                if (blurred) palette.backdrop = finished(blurred, YES, request.amoled ? 0.55 : 0.45, kFadeFrom, 1, 1, 0);
                CGImageRelease(blurred);
            }
            if (request.dissolve) {
                CGFloat aspect = (CGFloat)CGImageGetHeight(cg) / CGImageGetWidth(cg);
                size_t height = (size_t)MIN(kDissolveWidth * 2, MAX(kDissolveWidth / 2, round(kDissolveWidth * aspect)));
                CGImageRef blurred = newBlurred(cg, (size_t)kDissolveWidth, height, kDissolveSigma);
                if (blurred) palette.dissolve = finished(blurred, NO, 0, kFadeFrom, 0, kDissolveOpaque, 1);
                CGImageRelease(blurred);
            }
            static dispatch_once_t once;
            double ms = (CFAbsoluteTimeGetCurrent() - start) * 1000;
            dispatch_once(&once, ^{ SGLog(@"redesign kit: first palette %@ from %zux%zu in %.1f ms", palette.fieldColor, CGImageGetWidth(cg), CGImageGetHeight(cg), ms); });
        }
        dispatch_async(dispatch_get_main_queue(), ^{ completion(palette); });
    });
}

@end
