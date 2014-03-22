#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#include <getopt.h>
#include <stdio.h>
#include <stdlib.h>

const char* program_name;
double seconds;
const char* short_options = "hs:n:i:e:v";
const struct option long_options[] = {
    { "help",    0, NULL, 'h' },
    { "seconds", 1, NULL, 's' },
    { "image",   1, NULL, 'i' },
    { "verbose", 0, NULL, 'v' },
    { NULL,      0, NULL, 0   }   /* Required at end of array.  */
};

void invalid_image(FILE* stream, char * path) {
    fprintf (stream, "ERROR: You must have a valid PNG image at %s\n", path);
    exit(127);
}

void print_usage (FILE* stream, int exit_code) {
    fprintf (stream, "Usage:  %s [options]\n", program_name);
    fprintf (stream,
             "  -h  --help           Display this usage information.\n"
             "  -s  --seconds n      Animate for n seconds. (default: 2.0)\n"
             "  -i  --image          Custom image to use.\n"
             "  -v  --verbose        Print verbose messages.\n");
    exit (exit_code);
}

CGMutablePathRef pathInFrameForSize (CGRect screen, CGSize size) {
    CGMutablePathRef path = CGPathCreateMutable();
    CGPoint origin = CGPointMake(-size.width, -size.height);
    CGPoint destination = CGPointMake(screen.size.width + size.width, origin.y);
    CGFloat midpoint = (destination.x + origin.x) / 2.0;
    CGFloat peak = (screen.size.height + size.height) / 2.0;
    CGPathMoveToPoint(path, NULL, origin.x, origin.y);

    CGPathAddCurveToPoint(path, NULL, midpoint, peak,
                          midpoint, peak,
                          destination.x, destination.y);
    return path;
};

void animateLayerAlongPathForKey (CALayer *layer, CGMutablePathRef path, NSString *key) {
    CAKeyframeAnimation *animation = [CAKeyframeAnimation animationWithKeyPath:key];
    [animation setPath: path];
    [animation setDuration: seconds];
    [animation setCalculationMode: kCAAnimationLinear];
    [animation setRotationMode: nil];
    [layer addAnimation:animation forKey:key];
}

CALayer * layerForImageWithSize(CGImageRef image, CGSize size) {
    CALayer *layer = [CALayer layer];

    [layer setContents: (id)(image)];
    [layer setBounds:CGRectMake(0.0, 0.0, size.width, size.height)];
    [layer setPosition:CGPointMake(-size.width, -size.height)];

    return layer;
}

NSWindow * createTransparentWindow(CGRect screen) {
    NSWindow *window = [[NSWindow alloc] initWithContentRect: screen styleMask: NSBorderlessWindowMask
                                                  backing: NSBackingStoreBuffered
                                                  defer: NO];
    [window setBackgroundColor:[NSColor colorWithCalibratedHue:0 saturation:0 brightness:0 alpha:0.0]];
    [window setOpaque: NO];
    [window setIgnoresMouseEvents:YES];
    [window setLevel: NSFloatingWindowLevel];

    return window;
}

CGSize getImageSize(NSString *imagePath) {
    NSImage *image = [[NSImage alloc] initWithContentsOfFile: imagePath];
    if (![image isValid]) {
        invalid_image(stderr, (char *)[imagePath UTF8String]);
    }

    CGSize imageSize = image.size;

    [image dealloc];
    return imageSize;
}

CGImageRef createCGImage(NSString *imagePath) {
    CGDataProviderRef source = CGDataProviderCreateWithFilename([imagePath UTF8String]);
    NSString* theFileName = [imagePath pathExtension];
    CGImageRef cgimage;
    if ([theFileName isEqualToString: @"png"]) {
        cgimage = CGImageCreateWithPNGDataProvider(source, NULL, true, 0);
    }
    if ([theFileName isEqualToString: @"jpg"] || [theFileName isEqualToString: @"jpeg"]) {
        cgimage = CGImageCreateWithJPEGDataProvider(source, NULL, true, 0);
    }
    return cgimage;
}

CAEmitterLayer * getEmitterForImageInFrame (CGImageRef sparkleImage, CGSize imageSize) {
    static float base = 4.0;

    CAEmitterLayer *emitter = [[CAEmitterLayer alloc] init];
    emitter.emitterPosition = CGPointMake(-imageSize.width, -imageSize.height);
    emitter.emitterSize = CGSizeMake(imageSize.width, imageSize.height);
    CAEmitterCell *sparkle = [CAEmitterCell emitterCell];

    sparkle.contents = (id)(sparkleImage);

    sparkle.birthRate = 20.0/seconds + 15.0;
    sparkle.lifetime = 20.0;
    sparkle.lifetimeRange = 5.0;
    sparkle.name = @"sparkle";

    // Fade from white to purple
    //sparkle.color = CGColorCreateGenericRGB(1.0, 1.0, 1.0, 1.0);
    //sparkle.greenSpeed = -0.7;

    sparkle.minificationFilter = kCAFilterNearest;

    // Fade out
    sparkle.alphaSpeed = -1.0;

    // Shrink
    sparkle.scale = 2.0;
    sparkle.scaleRange = 2.0;
    sparkle.scaleSpeed = -1.0;

    // Fall away
    sparkle.velocity = -20.0;
    sparkle.velocityRange = 20.0;
    sparkle.yAcceleration = -100.0;
    sparkle.xAcceleration = -50.0;

    // Spin
    //sparkle.spin = -2.0;
    //sparkle.spinRange = 4.0;

    emitter.renderMode = kCAEmitterLayerAdditive;
    emitter.emitterShape = kCAEmitterLayerCuboid;
    emitter.emitterCells = [NSArray arrayWithObject:sparkle];
    return emitter;
}

void animateImage () {
    // Objective C
    [NSApplication sharedApplication];
    CGRect screen = NSScreen.mainScreen.frame;
    NSWindow *window = createTransparentWindow(screen);
    NSView *view = [[NSView alloc] initWithFrame:screen];
    // NSString *imagePath = [NSString stringWithFormat: @"%s" , imagePathString];

    // NSString *folder = [NSHomeDirectory() stringByAppendingPathComponent:@".unicornleap"];
    // NSString *folder = getcwd;
    // NSFileManager *NSFm;
    NSString *folder = @"../";
    // NSString *folder = [[NSFm currentDirectoryPath] stringByAppendingPathComponent];
    NSString *imagePath = [folder stringByAppendingPathComponent:@"gosling.png"];
    NSString *sparklePath = [folder stringByAppendingPathComponent:@"heygurl.png"];

    CGSize imageSize = getImageSize(imagePath);
    CGImageRef cgimage = createCGImage(imagePath);
    CGMutablePathRef arcPath;
    arcPath = pathInFrameForSize(screen, imageSize);
    CALayer *layer;
    CAEmitterLayer *emitter;
    double waitFor = seconds/2.5;
    NSRunLoop *runLoop = [NSRunLoop currentRunLoop];
    layer = layerForImageWithSize(cgimage, imageSize);




    CGDataProviderRef sparkleSource = CGDataProviderCreateWithFilename([sparklePath UTF8String]);
    CGImageRef sparkleImage = CGImageCreateWithPNGDataProvider(sparkleSource, NULL, true, 0);
    emitter = getEmitterForImageInFrame(sparkleImage, imageSize);

    [window setContentView: view];
    [window makeKeyAndOrderFront: nil];

    [view setWantsLayer: YES];
    [view.layer addSublayer: layer];
    [view.layer addSublayer: emitter];

    animateLayerAlongPathForKey(layer, arcPath, @"position");
    animateLayerAlongPathForKey(emitter, arcPath, @"emitterPosition");

    [runLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow: waitFor]];

    // Wait for animation to finish
    [runLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow: seconds - waitFor + 0.2]];
    [imagePath release];
    [view release];
    [window release];
    return;
}

int main (int argc, char * argv[]) {
    program_name = argv[0];

    // Defaults
    char* s = NULL;
    char* i = NULL;

    const char* image;
    int verbose = 0, num = 1;
    double sec = 2.0;

    // Parse options
    int next_option;

    do {
        next_option = getopt_long(argc, argv, short_options, long_options, NULL);
        switch(next_option)
        {
            case 's':
                s = optarg;
                break;

            case 'v':
                verbose = 1;
                break;

            case 'i':
                image = optarg;
                break;

            case 'h': print_usage(stdout, 0);
            case '?': print_usage(stderr, 1);
            case -1: break;
            default:  abort();
        }
    } while (next_option != -1);

    // Coerce string to double
    if (NULL != s) sec = strtod(s, NULL);
    if (! sec > 0.0) sec = 2.0;
    seconds = sec;

    if (verbose) {
        printf("Seconds: %f\n", seconds);
        printf("Image: %s\n", image);
    }

    animateImage();

    return 0;
}
