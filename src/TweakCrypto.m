#import "TweakCrypto.h"
#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonHMAC.h>
#import <Security/Security.h>

NSString *randomHexString(int byteCount) {
    uint8_t bytes[byteCount];
    (void)SecRandomCopyBytes(kSecRandomDefault, byteCount, bytes);
    NSMutableString *hex = [NSMutableString stringWithCapacity:byteCount * 2];
    for (int i = 0; i < byteCount; i++) {
        [hex appendFormat:@"%02x", bytes[i]];
    }
    return hex;
}

NSData *decryptPayload(NSData *data, NSData *key) {
    if (!data || !key) return nil;
    if (data.length < 48 + kCCBlockSizeAES128) return nil;

    const uint8_t *raw = data.bytes;
    const void *iv = raw;
    const void *ct = raw + 48;
    size_t ctLen = data.length - 48;

    NSMutableData *out = [NSMutableData dataWithLength:ctLen + kCCBlockSizeAES128];
    size_t moved = 0;
    CCCryptorStatus st = CCCrypt(kCCDecrypt, kCCAlgorithmAES, kCCOptionPKCS7Padding,
                                 key.bytes, kCCKeySizeAES256, iv,
                                 ct, ctLen,
                                 out.mutableBytes, out.length, &moved);
    if (st != kCCSuccess) return nil;

    out.length = moved;
    return out;
}

NSData *encryptPayload(NSData *plain, NSData *key) {
    if (!plain || !key) return nil;

    uint8_t iv[16];
    (void)SecRandomCopyBytes(kSecRandomDefault, sizeof(iv), iv);

    size_t ctBufLen = plain.length + kCCBlockSizeAES128;
    NSMutableData *ct = [NSMutableData dataWithLength:ctBufLen];
    size_t moved = 0;
    CCCryptorStatus st = CCCrypt(kCCEncrypt, kCCAlgorithmAES, kCCOptionPKCS7Padding,
                                 key.bytes, kCCKeySizeAES256, iv,
                                 plain.bytes, plain.length,
                                 ct.mutableBytes, ct.length, &moved);
    if (st != kCCSuccess) return nil;
    ct.length = moved;

    NSMutableData *hmacInput = [NSMutableData dataWithBytes:iv length:sizeof(iv)];
    [hmacInput appendData:ct];
    uint8_t hmac[CC_SHA256_DIGEST_LENGTH];
    CCHmac(kCCHmacAlgSHA256, key.bytes, kCCKeySizeAES256,
           hmacInput.bytes, hmacInput.length, hmac);

    NSMutableData *pkg = [NSMutableData dataWithBytes:iv length:sizeof(iv)];
    [pkg appendBytes:hmac length:sizeof(hmac)];
    [pkg appendData:ct];
    return pkg;
}
