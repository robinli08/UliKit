//
//  UKGraphics.m
//  Shovel
//
//  Created by Uli Kusterer on Thu Mar 25 2004.
//  Copyright (c) 2004 M. Uli Kusterer. All rights reserved.
//

#import "UKGraphics.h"
#if UK_GRAPHICS_USE_HITHEME
#if MAC_OS_X_VERSION_MAX_ALLOWED >= MAC_OS_X_VERSION_10_3
#import <Carbon/Carbon.h>
#else
#undef UK_GRAPHICS_USE_HITHEME
#endif
#endif


void	UKDrawWhiteBezel( NSRect box, NSRect clipBox )
{
	UKDrawDropHighlightedWhiteBezel( NO, box, clipBox );
}


void	UKDrawDropHighlightedWhiteBezel( BOOL doHighlight, NSRect box, NSRect clipBox )
{
	UKDrawDropHighlightedEditableWhiteBezel( doHighlight, NO, box, clipBox );
}


void	UKDrawDropHighlightedEditableWhiteBezel( BOOL doHighlight, BOOL isEditable, NSRect box, NSRect clipBox )
{
    NSRect			drawBox = box;
    [NSGraphicsContext saveGraphicsState];
    float lw = [NSBezierPath defaultLineWidth];
    [NSBezierPath setDefaultLineWidth: 1];
        
    #if UK_GRAPHICS_USE_HITHEME
    unsigned long        sysVersion;
    
    if( noErr != Gestalt( gestaltSystemVersion, (long*) &sysVersion ) )
        sysVersion = 0;
    
    if( sysVersion < 0x00001030 )
    {
    #endif
        // Fix up rect so it draws *on* the pixels:
        drawBox.origin.x += 0.5;
        drawBox.origin.y += 0.5;
        drawBox.size.width -= 1;
        drawBox.size.height -= 1;
    #if UK_GRAPHICS_USE_HITHEME
    }
    #endif
    
    // Draw background in white:
    [[NSColor controlBackgroundColor] set];
    [NSBezierPath fillRect: drawBox];
    
    
    #if UK_GRAPHICS_USE_HITHEME
    if( sysVersion >= 0x00001030 )
    {
        CGContextRef            context = [[NSGraphicsContext currentContext] graphicsPort];
        HIThemeFrameDrawInfo    info = { 0, kHIThemeFrameTextFieldSquare, kThemeStateActive, NO };
        drawBox = NSInsetRect( drawBox, 1, 1 );
       
        if( !isEditable )
            info.state = kThemeStateInactive;
        
        HIThemeDrawFrame( (HIRect*) &drawBox, &info, context, kHIThemeOrientationInverted );
        CGContextSynchronize( context );
        
        if( isEditable )
            drawBox.size.height -= 1;
    }
    else
    {
    #endif
        // Draw three edges in grey
        if( isEditable )
        {
            drawBox.size.height--;
            [[[NSColor lightGrayColor] colorWithAlphaComponent: 0.8] set];
        }
        else
            [[NSColor lightGrayColor] set];
        [NSBezierPath strokeRect: drawBox];
        if( isEditable )
            drawBox.size.height++;

        // Draw top a little darker:
        [[NSColor grayColor] set];
        [NSBezierPath strokeLineFromPoint: NSMakePoint(drawBox.origin.x +drawBox.size.width +1, drawBox.origin.y +drawBox.size.height)
            toPoint: NSMakePoint(drawBox.origin.x -1, drawBox.origin.y +drawBox.size.height)];
    #if UK_GRAPHICS_USE_HITHEME
    }
    #endif
    
    // Draw drop highlight if requested:
    if( doHighlight )
    {
        drawBox = NSInsetRect( drawBox, 1, 1 );
        
        [[[NSColor selectedControlColor] colorWithAlphaComponent: 0.8] set];
        [NSBezierPath setDefaultLineWidth: 2];
        [NSBezierPath strokeRect: drawBox];
        [[NSColor blackColor] set];
    }
    
    [NSBezierPath setDefaultLineWidth: lw];
    [NSGraphicsContext restoreGraphicsState];
}


void	UKDrawGenericWell( NSRect box, NSRect clipBox )
{
    NSImageCell*    borderCell = [[[NSImageCell alloc] initImageCell: [[[NSImage alloc] initWithSize: NSMakeSize(2,2)] autorelease]] autorelease];
    [borderCell setImageFrameStyle: NSImageFrameGrayBezel];
    [borderCell drawWithFrame: box inView: nil];
}



static float	PerceptualGlossFractionForColor(float *inputComponents)
{
    const float REFLECTION_SCALE_NUMBER = 0.2;
    const float NTSC_RED_FRACTION = 0.299;
    const float NTSC_GREEN_FRACTION = 0.587;
    const float NTSC_BLUE_FRACTION = 0.114;

    float glossScale =
        NTSC_RED_FRACTION * inputComponents[0] +
        NTSC_GREEN_FRACTION * inputComponents[1] +
        NTSC_BLUE_FRACTION * inputComponents[2];
    glossScale = pow(glossScale, REFLECTION_SCALE_NUMBER);
    return glossScale;
}


static void	PerceptualCausticColorForColor(float *inputComponents, float *outputComponents)
{
    const float CAUSTIC_FRACTION = 0.60;
    const float COSINE_ANGLE_SCALE = 1.4;
    const float MIN_RED_THRESHOLD = 0.95;
    const float MAX_BLUE_THRESHOLD = 0.7;
    const float GRAYSCALE_CAUSTIC_SATURATION = 0.2;
    
    NSColor *source =
        [NSColor
            colorWithCalibratedRed:inputComponents[0]
            green:inputComponents[1]
            blue:inputComponents[2]
            alpha:inputComponents[3]];

    float hue, saturation, brightness, alpha;
    [source getHue:&hue saturation:&saturation brightness:&brightness alpha:&alpha];

    float targetHue, targetSaturation, targetBrightness;
    [[NSColor yellowColor] getHue:&targetHue saturation:&targetSaturation brightness:&targetBrightness alpha:&alpha];
    
    if (saturation < 1e-3)
    {
        hue = targetHue;
        saturation = GRAYSCALE_CAUSTIC_SATURATION;
    }

    if (hue > MIN_RED_THRESHOLD)
    {
        hue -= 1.0;
    }
    else if (hue > MAX_BLUE_THRESHOLD)
    {
        [[NSColor magentaColor] getHue:&targetHue saturation:&targetSaturation brightness:&targetBrightness alpha:&alpha];
    }

    float scaledCaustic = CAUSTIC_FRACTION * 0.5 * (1.0 + cos(COSINE_ANGLE_SCALE * M_PI * (hue - targetHue)));

    NSColor *targetColor =
        [NSColor
            colorWithCalibratedHue:hue * (1.0 - scaledCaustic) + targetHue * scaledCaustic
            saturation:saturation
            brightness:brightness * (1.0 - scaledCaustic) + targetBrightness * scaledCaustic
            alpha:inputComponents[3]];
    [targetColor getComponents:outputComponents];
}


typedef struct
{
    float color[4];
    float caustic[4];
    float expCoefficient;
    float expScale;
    float expOffset;
    float initialWhite;
    float finalWhite;
} GlossParameters;

void	UKGlossInterpolation(void *info, const float *input, float *output)
{
    GlossParameters *params = (GlossParameters *)info;

    float progress = *input;
    if (progress < 0.5)
    {
        progress = progress * 2.0;

        progress =
            1.0 - params->expScale * (expf(progress * -params->expCoefficient) - params->expOffset);

        float currentWhite = progress * (params->finalWhite - params->initialWhite) + params->initialWhite;
        
        output[0] = params->color[0] * (1.0 - currentWhite) + currentWhite;
        output[1] = params->color[1] * (1.0 - currentWhite) + currentWhite;
        output[2] = params->color[2] * (1.0 - currentWhite) + currentWhite;
        output[3] = params->color[3] * (1.0 - currentWhite) + currentWhite;
    }
    else
    {
        progress = (progress - 0.5) * 2.0;

        progress = params->expScale *
            (expf((1.0 - progress) * -params->expCoefficient) - params->expOffset);

        output[0] = params->color[0] * (1.0 - progress) + params->caustic[0] * progress;
        output[1] = params->color[1] * (1.0 - progress) + params->caustic[1] * progress;
        output[2] = params->color[2] * (1.0 - progress) + params->caustic[2] * progress;
        output[3] = params->color[3] * (1.0 - progress) + params->caustic[3] * progress;
    }
}


void	UKDrawGlossGradientOfColorInRect( NSColor *color, NSRect inRect )
{
	CGContextRef context = (CGContextRef) [[NSGraphicsContext currentContext] graphicsPort];
	
    const float EXP_COEFFICIENT = 1.2;
    const float REFLECTION_MAX = 0.60;
    const float REFLECTION_MIN = 0.20;
    
    GlossParameters params;
    
    params.expCoefficient = EXP_COEFFICIENT;
    params.expOffset = expf(-params.expCoefficient);
    params.expScale = 1.0 / (1.0 - params.expOffset);

    NSColor *source =
        [color colorUsingColorSpaceName:NSCalibratedRGBColorSpace];
    [source getComponents:params.color];
    if ([source numberOfComponents] == 3)
    {
        params.color[3] = 1.0;
    }
    
    PerceptualCausticColorForColor(params.color, params.caustic);
    
    float glossScale = PerceptualGlossFractionForColor(params.color);

    params.initialWhite = glossScale * REFLECTION_MAX;
    params.finalWhite = glossScale * REFLECTION_MIN;

    static const float input_value_range[2] = {0, 1};
    static const float output_value_ranges[8] = {0, 1, 0, 1, 0, 1, 0, 1};
    CGFunctionCallbacks callbacks = {0, UKGlossInterpolation, NULL};
    
    CGFunctionRef gradientFunction = CGFunctionCreate(
        (void *)&params,
        1, // number of input values to the callback
        input_value_range,
        4, // number of components (r, g, b, a)
        output_value_ranges,
        &callbacks);
    
    CGPoint startPoint = CGPointMake(NSMinX(inRect), NSMaxY(inRect));
    CGPoint endPoint = CGPointMake(NSMinX(inRect), NSMinY(inRect));
	
	if( [[NSGraphicsContext currentContext] isFlipped] )
	{
		startPoint = CGPointMake(NSMinX(inRect), NSMinY(inRect));
		endPoint = CGPointMake(NSMinX(inRect), NSMaxY(inRect));
	}
	
    CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
    CGShadingRef shading = CGShadingCreateAxial(colorspace, startPoint,
        endPoint, gradientFunction, FALSE, FALSE);
    
    union _ {NSRect ns; CGRect cg;};
	
    CGContextSaveGState(context);
    CGContextClipToRect(context, ((union _ *)&inRect)->cg );
    CGContextDrawShading(context, shading);
    CGContextRestoreGState(context);
    
    CGShadingRelease(shading);
    CGColorSpaceRelease(colorspace);
    CGFunctionRelease(gradientFunction);
}