#import <Foundation/Foundation.h>

NSString *randomHexString(int byteCount);
NSData *decryptPayload(NSData *data, NSData *key);
NSData *encryptPayload(NSData *plain, NSData *key);
