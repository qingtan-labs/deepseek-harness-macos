#import <Foundation/Foundation.h>

static void AppendType(NSMutableData *data, const char type[4]) {
    [data appendBytes:type length:4];
}

static void AppendBE32(NSMutableData *data, uint32_t value) {
    uint32_t bigEndian = CFSwapInt32HostToBig(value);
    [data appendBytes:&bigEndian length:sizeof(bigEndian)];
}

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        if (argc != 3) return 64;
        NSString *directory = [NSString stringWithUTF8String:argv[1]];
        NSArray<NSArray<NSString *> *> *entries = @[
            @[ @"icp4", @"icon_16x16.png" ],
            @[ @"icp5", @"icon_32x32.png" ],
            @[ @"icp6", @"icon_32x32@2x.png" ],
            @[ @"ic07", @"icon_128x128.png" ],
            @[ @"ic08", @"icon_256x256.png" ],
            @[ @"ic09", @"icon_512x512.png" ],
            @[ @"ic10", @"icon_512x512@2x.png" ]
        ];
        NSMutableArray<NSDictionary *> *chunks = [NSMutableArray array];
        NSUInteger totalLength = 8;
        for (NSArray<NSString *> *entry in entries) {
            NSData *png = [NSData dataWithContentsOfFile:[directory stringByAppendingPathComponent:entry[1]]];
            if (png.length == 0) return 1;
            [chunks addObject:@{ @"type": entry[0], @"data": png }];
            totalLength += 8 + png.length;
        }
        if (totalLength > UINT32_MAX) return 1;
        NSMutableData *icns = [NSMutableData dataWithCapacity:totalLength];
        AppendType(icns, "icns");
        AppendBE32(icns, (uint32_t)totalLength);
        for (NSDictionary *chunk in chunks) {
            NSString *type = chunk[@"type"];
            NSData *png = chunk[@"data"];
            AppendType(icns, type.UTF8String);
            AppendBE32(icns, (uint32_t)(8 + png.length));
            [icns appendData:png];
        }
        return [icns writeToFile:[NSString stringWithUTF8String:argv[2]] atomically:YES] ? 0 : 1;
    }
}
