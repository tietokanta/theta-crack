#import "TweakHTTP.h"
#import "TweakConfig.h"
#import "TweakCrypto.h"
#import <objc/runtime.h>

@interface NSURLSession (ThetaCrack)
- (id)theta_dataTaskWithRequest:(NSURLRequest *)request completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler;
@end

static id (*orig_dataTaskWithRequest)(id, SEL, NSURLRequest *, void(^)(NSData *, NSURLResponse *, NSError *));

static NSData *bodyDataFromRequest(NSURLRequest *request) {
    if (request.HTTPBody) return request.HTTPBody;

    NSInputStream *stream = request.HTTPBodyStream;
    if (!stream) return nil;

    NSMutableData *buf = [NSMutableData data];
    [stream open];
    uint8_t tmp[4096];
    NSInteger n;
    while ((n = [stream read:tmp maxLength:sizeof(tmp)]) > 0) {
        [buf appendBytes:tmp length:(NSUInteger)n];
    }
    [stream close];
    return buf.length ? buf : nil;
}

static NSData *buildFakeEncryptedResponse(NSData *rawBody, NSData *key, NSString *endpoint) {
    if (!rawBody || !key) return nil;

    NSString *b64 = [[NSString alloc] initWithData:rawBody encoding:NSUTF8StringEncoding];
    b64 = [b64 stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSData *encrypted = [[NSData alloc] initWithBase64EncodedString:b64 options:NSDataBase64DecodingIgnoreUnknownCharacters];
    if (!encrypted) {
        encrypted = rawBody;
    }

    NSData *plain = decryptPayload(encrypted, key);
    if (!plain) return nil;

    NSError *err = nil;
    NSDictionary *reqJSON = [NSJSONSerialization JSONObjectWithData:plain options:0 error:&err];
    if (!reqJSON) return nil;

    NSString *clientNonce = reqJSON[@"nonce"];

    long long ts = (long long)([[NSDate date] timeIntervalSince1970] * 1000);
    NSMutableDictionary *resp = [@{
        @"ok":       @YES,
        @"status":   @"active",
        @"ts":       @(ts),
        @"nonce":    randomHexString(16),
    } mutableCopy];
    if (clientNonce) resp[@"reqNonce"] = clientNonce;

    NSData *respJSON = [NSJSONSerialization dataWithJSONObject:resp options:0 error:nil];
    if (!respJSON) return nil;

    NSData *respEnc = encryptPayload(respJSON, key);
    if (!respEnc) return nil;

    return [[respEnc base64EncodedStringWithOptions:0] dataUsingEncoding:NSUTF8StringEncoding];
}

static void injectFakeResponse(NSURLRequest *capturedRequest,
                               NSURL *url,
                               NSData *key,
                               NSString *endpoint,
                               NSData *realData,
                               NSURLResponse *realResponse,
                               NSError *realError,
                               void(^completionHandler)(NSData *, NSURLResponse *, NSError *))
{
    NSData *body = bodyDataFromRequest(capturedRequest);
    if (!body) {
        completionHandler(realData, realResponse, realError);
        return;
    }

    NSData *fakeData = buildFakeEncryptedResponse(body, key, endpoint);
    if (!fakeData) {
        completionHandler(realData, realResponse, realError);
        return;
    }

    NSHTTPURLResponse *fakeResp = [[NSHTTPURLResponse alloc]
                                   initWithURL:url
                                   statusCode:200
                                   HTTPVersion:@"HTTP/1.1"
                                   headerFields:@{@"Content-Type": @"text/plain"}];
    completionHandler(fakeData, fakeResp, nil);
}

static id replaced_dataTaskWithRequest(id self, SEL _cmd, NSURLRequest *request,
                                       void(^completionHandler)(NSData *, NSURLResponse *, NSError *))
{
    NSURL *url = request.URL;
    NSString *path = url.path;

    if ([path isEqualToString:@"/api/activate"]) {
        NSURLRequest *captured = [request copy];
        NSData *key = [NSData dataWithBytes:kActivationKey length:kCCKeySizeAES256];

        void(^fake)(NSData*, NSURLResponse*, NSError*) = ^(NSData *d, NSURLResponse *r, NSError *e){
            injectFakeResponse(captured, url, key, @"activate", d, r, e, completionHandler);
        };
        return orig_dataTaskWithRequest(self, _cmd, request, fake);
    }

    if ([path isEqualToString:@"/api/heartbeat"]) {
        NSURLRequest *captured = [request copy];

        static NSData *heartbeatKey = nil;
        static dispatch_once_t once;
        dispatch_once(&once, ^{
            BOOL allZero = YES;
            for (size_t i = 0; i < kCCKeySizeAES256; i++) {
                if (kHeartbeatKey[i] != 0) { allZero = NO; break; }
            }
            if (!allZero) {
                heartbeatKey = [[NSData alloc] initWithBytes:kHeartbeatKey length:kCCKeySizeAES256];
            }
        });

        if (!heartbeatKey) {
            return orig_dataTaskWithRequest(self, _cmd, request, completionHandler);
        }

        void(^fake)(NSData*, NSURLResponse*, NSError*) = ^(NSData *d, NSURLResponse *r, NSError *e){
            injectFakeResponse(captured, url, heartbeatKey, @"heartbeat", d, r, e, completionHandler);
        };
        return orig_dataTaskWithRequest(self, _cmd, request, fake);
    }

    return orig_dataTaskWithRequest(self, _cmd, request, completionHandler);
}

void installThetaHTTPHook(void) {
    Class cls = [NSURLSession class];
    SEL origSel = @selector(dataTaskWithRequest:completionHandler:);
    SEL newSel = @selector(theta_dataTaskWithRequest:completionHandler:);

    Method origMethod = class_getInstanceMethod(cls, origSel);
    if (!origMethod) return;

    orig_dataTaskWithRequest = (id (*)(id, SEL, NSURLRequest *, void(^)(NSData *, NSURLResponse *, NSError *)))method_getImplementation(origMethod);

    if (!class_getInstanceMethod(cls, newSel)) {
        class_addMethod(cls, newSel, (IMP)replaced_dataTaskWithRequest, method_getTypeEncoding(origMethod));
    }

    Method newMethod = class_getInstanceMethod(cls, newSel);
    method_exchangeImplementations(origMethod, newMethod);
}
