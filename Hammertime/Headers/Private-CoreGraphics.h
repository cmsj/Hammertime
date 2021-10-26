//
//  Private-CoreGraphics.h
//  Hammertime
//
//  Created by Chris Jones on 21/10/2021.
//

#import <AppKit/AppKit.h>

#ifndef Private_CoreGraphics_h
#define Private_CoreGraphics_h

// DisplayServices private API used for getting/setting display brightness on Apple Silicon machines
int DisplayServicesGetBrightness(CGDirectDisplayID display, float *brightness);
int DisplayServicesSetBrightness(CGDirectDisplayID display, float brightness);

// CoreGraphics DisplayMode struct used in private APIs
typedef struct {
    uint32_t modeNumber;
    uint32_t flags;
    uint32_t width;
    uint32_t height;
    uint32_t depth;
    uint8_t unknown[170];
    uint16_t freq;
    uint8_t more_unknown[16];
    float density;
} CGSDisplayMode;

// CoreGraphics private APIs with support for scaled (retina) display modes
void CGSGetCurrentDisplayMode(CGDirectDisplayID display, int *modeNum);
void CGSConfigureDisplayMode(CGDisplayConfigRef config, CGDirectDisplayID display, int modeNum);
void CGSGetNumberOfDisplayModes(CGDirectDisplayID display, int *nModes);
void CGSGetDisplayModeDescriptionOfLength(CGDirectDisplayID display, int idx, CGSDisplayMode *mode, int length);

// CoreGraphics private accessibility APIs
CG_EXTERN bool CGDisplayUsesForceToGray(void);
CG_EXTERN void CGDisplayForceToGray(bool forceToGray);
CG_EXTERN bool CGDisplayUsesInvertedPolarity(void);
CG_EXTERN void CGDisplaySetInvertedPolarity(bool invertedPolarity);

// IOKit private APIs
enum {
    // from <IOKit/graphics/IOGraphicsTypesPrivate.h>
    kIOFBSetTransform = 0x00000400,
};

#endif /* Private_CoreGraphics_h */
