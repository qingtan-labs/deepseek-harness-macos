#import <Cocoa/Cocoa.h>

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 3) return 64;
        NSApplicationLoad();

        NSImage *officialWhale = [[NSImage alloc] initWithContentsOfFile:[NSString stringWithUTF8String:argv[1]]];
        if (officialWhale == nil) return 1;

        const CGFloat side = 1024.0;
        NSImage *canvas = [[NSImage alloc] initWithSize:NSMakeSize(side, side)];
        [canvas lockFocus];
        [[NSColor whiteColor] setFill];
        [[NSBezierPath bezierPathWithRoundedRect:NSMakeRect(0, 0, side, side)
                                         xRadius:230
                                         yRadius:230] fill];
        [officialWhale drawInRect:NSMakeRect(132, 132, 760, 760)
                      fromRect:NSZeroRect
                     operation:NSCompositingOperationSourceOver
                      fraction:1.0];
        [canvas unlockFocus];

        NSBitmapImageRep *bitmap = [NSBitmapImageRep imageRepWithData:canvas.TIFFRepresentation];
        NSData *png = [bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
        return [png writeToFile:[NSString stringWithUTF8String:argv[2]] atomically:YES] ? 0 : 1;
    }
}
