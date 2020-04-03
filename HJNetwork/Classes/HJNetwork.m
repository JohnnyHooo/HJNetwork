//
//  HJNetwork.m
//  HJNetwork
//
//  Created by Johnny on 18/4/19.
//  Copyright © 2018年 Johnny. All rights reserved.
//

#import "HJNetwork.h"
#import "YYCache.h"
#import "AFNetworkActivityIndicatorManager.h"
#import "AFNetworking.h"
#import <SystemConfiguration/CaptiveNetwork.h>
#import <CommonCrypto/CommonDigest.h>

#ifdef DEBUG
#define ATLog(FORMAT, ...) fprintf(stderr,"[%s:%d行] %s\n",[[[NSString stringWithUTF8String:__FILE__] lastPathComponent] UTF8String], __LINE__, [[NSString stringWithFormat:FORMAT, ##__VA_ARGS__] UTF8String]);
#else
#define ATLog(...)
#endif


@implementation HJNetwork

static BOOL _logEnabled;
static BOOL _cacheVersionEnabled;
static NSMutableArray *_allSessionTask;
static NSDictionary *_baseParameters;
static NSArray *_filtrationCacheKey;
static AFHTTPSessionManager *_sessionManager;
static NSString *const NetworkResponseCache = @"HJNetworkResponseCache";
static NSString * _baseURL;
static NSString * _cacheVersion;
static YYCache *_dataCache;

/*所有的请求task数组*/
+ (NSMutableArray *)allSessionTask{
    if (!_allSessionTask) {
        _allSessionTask = [NSMutableArray array];
    }
    return _allSessionTask;
}


#pragma mark -- 初始化相关属性
+ (void)initialize{
    _sessionManager = [AFHTTPSessionManager manager];
    //设置请求超时时间
    _sessionManager.requestSerializer.timeoutInterval = 30.f;
    //设置服务器返回结果的类型:JSON(AFJSONResponseSerializer,AFHTTPResponseSerializer)
    _sessionManager.responseSerializer = [AFJSONResponseSerializer serializer];
    _sessionManager.requestSerializer = [AFJSONRequestSerializer serializer];
    _sessionManager.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/html", @"text/json", @"text/plain", @"text/javascript", @"text/xml", @"image/*", nil];
    //开始监测网络状态
    [[AFNetworkReachabilityManager sharedManager] startMonitoring];
    //打开状态栏菊花
    [AFNetworkActivityIndicatorManager sharedManager].enabled = YES;
    _dataCache = [YYCache cacheWithName:NetworkResponseCache];
    _logEnabled = YES;
    _cacheVersionEnabled = NO;
}

/**是否按App版本号缓存网络请求内容(默认关闭)*/
+ (void)setCacheVersionEnabled:(BOOL)bFlag
{
    _cacheVersionEnabled = bFlag;
    if (bFlag) {
        if (!_cacheVersion.length) {
            _cacheVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
        }
        _dataCache = [YYCache cacheWithName:[NSString stringWithFormat:@"%@(%@)",NetworkResponseCache,_cacheVersion]];
    }else{
        _dataCache = [YYCache cacheWithName:NetworkResponseCache];
    }
}

/**使用自定义缓存版本号*/
+ (void)setCacheVersion:(NSString*)version
{
    _cacheVersion = version;
    [self setCacheVersionEnabled:YES];
}


/** 输出Log信息开关*/
+ (void)setLogEnabled:(BOOL)bFlag
{
    _logEnabled = bFlag;
}


/*过滤缓存Key*/
+ (void)setFiltrationCacheKey:(NSArray *)filtrationCacheKey
{
    _filtrationCacheKey = filtrationCacheKey;
}

/**设置接口根路径, 设置后所有的网络访问都使用相对路径*/
+ (void)setBaseURL:(NSString *)baseURL
{
    _baseURL = baseURL;
}

/**设置接口请求头*/
+ (void)setHeadr:(NSDictionary *)heder
{
    for (NSString * key in heder.allKeys) {
        [_sessionManager.requestSerializer setValue:heder[key] forHTTPHeaderField:key];
    }
}

/**设置接口基本参数*/
+ (void)setBaseParameters:(NSDictionary *)parameters
{
    _baseParameters = parameters;
}

/**设置请求超时时间(默认30s) */
+ (void)setRequestTimeoutInterval:(NSTimeInterval)time{
    _sessionManager.requestSerializer.timeoutInterval = time;
}

/*实时获取网络状态*/
+ (void)getNetworkStatusWithBlock:(HJNetworkStatus)networkStatus{
    [[AFNetworkReachabilityManager sharedManager] setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
        switch (status) {
            case AFNetworkReachabilityStatusUnknown:
                networkStatus ? networkStatus(HJNetworkStatusUnknown) : nil;
                break;
            case AFNetworkReachabilityStatusNotReachable:
                networkStatus ? networkStatus(HJNetworkStatusNotReachable) : nil;
                break;
            case AFNetworkReachabilityStatusReachableViaWWAN:
                networkStatus ? networkStatus(HJNetworkStatusReachableWWAN) : nil;
                break;
            case AFNetworkReachabilityStatusReachableViaWiFi:
                networkStatus ? networkStatus(HJNetworkStatusReachableWiFi) : nil;
                break;
            default:
                break;
        }
    }];
}

/*判断是否有网*/
+ (BOOL)isNetwork{
    return [AFNetworkReachabilityManager sharedManager].reachable;
}

/*是否是手机网络*/
+ (BOOL)isWWANNetwork{
    return [AFNetworkReachabilityManager sharedManager].reachableViaWWAN;
}

/*是否是WiFi网络*/
+ (BOOL)isWiFiNetwork{
    return [AFNetworkReachabilityManager sharedManager].reachableViaWiFi;
}

/*取消所有Http请求*/
+ (void)cancelAllRequest{
    @synchronized (self) {
        [[self allSessionTask] enumerateObjectsUsingBlock:^(NSURLSessionTask  *_Nonnull task, NSUInteger idx, BOOL * _Nonnull stop) {
            [task cancel];
        }];
        [[self allSessionTask] removeAllObjects];
    }
}

/*取消指定URL的Http请求*/
+ (void)cancelRequestWithURL:(NSString *)url{
    if (!url) { return; }
    @synchronized (self) {
        [[self allSessionTask] enumerateObjectsUsingBlock:^(NSURLSessionTask  *_Nonnull task, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([task.currentRequest.URL.absoluteString hasPrefix:url]) {
                [task cancel];
                [[self allSessionTask] removeObject:task];
                *stop = YES;
            }
        }];
    }
}


/** 清空接口请求头 */
+ (void)clearAuthorizationHeader
{
    [_sessionManager.requestSerializer clearAuthorizationHeader];
}

/**是否打开网络加载菊花(默认打开)*/
+ (void)openNetworkActivityIndicator:(BOOL)open{
    [[AFNetworkActivityIndicatorManager sharedManager] setEnabled:open];
}



#pragma mark -- 缓存描述文字
+ (NSString *)cachePolicyStr:(HJCachePolicy)cachePolicy
{
    switch (cachePolicy) {
        case HJCachePolicyIgnoreCache:
            return @"只从网络获取数据，且数据不会缓存在本地";
            break;
        case HJCachePolicyCacheOnly:
            return @"只从缓存读数据，如果缓存没有数据，返回一个空";
            break;
        case HJCachePolicyNetworkOnly:
            return @"先从网络获取数据，同时会在本地缓存数据";
            break;
        case HJCachePolicyCacheElseNetwork:
            return @"先从缓存读取数据，如果没有再从网络获取";
            break;
        case HJCachePolicyNetworkElseCache:
            return @"先从网络获取数据，如果没有再从缓存读取数据";
            break;
        case HJCachePolicyCacheThenNetwork:
            return @"先从缓存读取数据，然后再从网络获取数据，Block将产生两次调用";
            break;
            
        default:
            return @"未知缓存策略，采用HJCachePolicyIgnoreCache策略";
            break;
    }
}

#pragma mark -- GET请求
+ (void)GETWithURL:(NSString *)url
        parameters:(NSDictionary *)parameters
        headers:(NSDictionary *)headers
       cachePolicy:(HJCachePolicy)cachePolicy
           callback:(HJHttpRequest)callback
{
    [self HTTPWithMethod:HJRequestMethodGET url:url parameters:parameters headers:headers cachePolicy:cachePolicy callback:callback];
}
///不推荐使用
+ (void)GETWithURL:(NSString *)url parameters:(NSDictionary *)parameters cachePolicy:(HJCachePolicy)cachePolicy callback:(HJHttpRequest)callback
{
    [self GETWithURL:url parameters:parameters headers:[_sessionManager.requestSerializer HTTPRequestHeaders] cachePolicy:cachePolicy callback:callback];
}



#pragma mark -- POST请求
+ (void)POSTWithURL:(NSString *)url
         parameters:(NSDictionary *)parameters
         headers:(NSDictionary *)headers
        cachePolicy:(HJCachePolicy)cachePolicy
            callback:(HJHttpRequest)callback
{
    [self HTTPWithMethod:HJRequestMethodPOST url:url parameters:parameters headers:headers cachePolicy:cachePolicy callback:callback];
}
///不推荐使用
+ (void)POSTWithURL:(NSString *)url parameters:(NSDictionary *)parameters cachePolicy:(HJCachePolicy)cachePolicy callback:(HJHttpRequest)callback
{
    [self POSTWithURL:url parameters:parameters headers:[_sessionManager.requestSerializer HTTPRequestHeaders] cachePolicy:cachePolicy callback:callback];
}


#pragma mark -- HEAD请求
+ (void)HEADWithURL:(NSString *)url
         parameters:(NSDictionary *)parameters
         headers:(NSDictionary *)headers
        cachePolicy:(HJCachePolicy)cachePolicy
            callback:(HJHttpRequest)callback
{
    [self HTTPWithMethod:HJRequestMethodHEAD url:url parameters:parameters headers:headers cachePolicy:cachePolicy callback:callback];
}
///不推荐使用
+ (void)HEADWithURL:(NSString *)url parameters:(NSDictionary *)parameters cachePolicy:(HJCachePolicy)cachePolicy callback:(HJHttpRequest)callback
{
    [self HEADWithURL:url parameters:parameters headers:[_sessionManager.requestSerializer HTTPRequestHeaders] cachePolicy:cachePolicy callback:callback];
}



#pragma mark -- PUT请求
+ (void)PUTWithURL:(NSString *)url
        parameters:(NSDictionary *)parameters
        headers:(NSDictionary *)headers
       cachePolicy:(HJCachePolicy)cachePolicy
           callback:(HJHttpRequest)callback
{
    [self HTTPWithMethod:HJRequestMethodPUT url:url parameters:parameters headers:headers cachePolicy:cachePolicy callback:callback];
}
///不推荐使用
+ (void)PUTWithURL:(NSString *)url parameters:(NSDictionary *)parameters cachePolicy:(HJCachePolicy)cachePolicy callback:(HJHttpRequest)callback
{
    [self PUTWithURL:url parameters:parameters headers:[_sessionManager.requestSerializer HTTPRequestHeaders] cachePolicy:cachePolicy callback:callback];
}



#pragma mark -- PATCH请求
+ (void)PATCHWithURL:(NSString *)url
          parameters:(NSDictionary *)parameters
          headers:(NSDictionary *)headers
         cachePolicy:(HJCachePolicy)cachePolicy
             callback:(HJHttpRequest)callback
{
    [self HTTPWithMethod:HJRequestMethodPATCH url:url parameters:parameters headers:headers cachePolicy:cachePolicy callback:callback];
}
///不推荐使用
+ (void)PATCHWithURL:(NSString *)url parameters:(NSDictionary *)parameters cachePolicy:(HJCachePolicy)cachePolicy callback:(HJHttpRequest)callback
{
    [self PATCHWithURL:url parameters:parameters headers:[_sessionManager.requestSerializer HTTPRequestHeaders] cachePolicy:cachePolicy callback:callback];
}



#pragma mark -- DELETE请求
+ (void)DELETEWithURL:(NSString *)url
           parameters:(NSDictionary *)parameters
              headers:(NSDictionary *)headers
          cachePolicy:(HJCachePolicy)cachePolicy
              callback:(HJHttpRequest)callback
{
    [self HTTPWithMethod:HJRequestMethodDELETE url:url parameters:parameters headers:headers cachePolicy:cachePolicy callback:callback];
}
///不推荐使用
+ (void)DELETEWithURL:(NSString *)url parameters:(NSDictionary *)parameters cachePolicy:(HJCachePolicy)cachePolicy callback:(HJHttpRequest)callback
{
    [self DELETEWithURL:url parameters:parameters headers:[_sessionManager.requestSerializer HTTPRequestHeaders] cachePolicy:cachePolicy callback:callback];
}



+ (void)HTTPWithMethod:(HJRequestMethod)method
                    url:(NSString *)url
             parameters:(NSDictionary *)parameters
               headers:(NSDictionary *)headers
            cachePolicy:(HJCachePolicy)cachePolicy
                callback:(HJHttpRequest)callback
{
    if (_baseURL.length) {
        url = [NSString stringWithFormat:@"%@%@",_baseURL,url];
    }
    if (_baseParameters.count) {
        NSMutableDictionary * mutableBaseParameters = [NSMutableDictionary dictionaryWithDictionary:parameters];
        [mutableBaseParameters addEntriesFromDictionary:_baseParameters];
        parameters = [mutableBaseParameters copy];
    }
    
    if (_logEnabled) {
        ATLog(@"\n请求参数 = %@\n请求URL = %@\n请求方式 = %@\n缓存策略 = %@\n版本缓存 = %@",parameters ? [self jsonToString:parameters]:@"空", url, [self getMethodStr:method], [self cachePolicyStr:cachePolicy], _cacheVersionEnabled? @"启用":@"未启用");
    }
    
    if (cachePolicy == HJCachePolicyIgnoreCache) {
        //只从网络获取数据，且数据不会缓存在本地
        [self httpWithMethod:method url:url parameters:parameters headers:headers callback:callback];
    }else if (cachePolicy == HJCachePolicyCacheOnly){
        //只从缓存读数据，如果缓存没有数据，返回一个空。
        [self httpCacheForURL:url parameters:parameters withBlock:^(id<NSCoding> object) {
            callback ? callback(object, YES, nil) : nil;
        }];
    }else if (cachePolicy == HJCachePolicyNetworkOnly){
        //先从网络获取数据，同时会在本地缓存数据
        [self httpWithMethod:method url:url parameters:parameters headers:headers callback:^(id responseObject, BOOL isCache, NSError *error) {
            callback ? callback(responseObject, NO, error) : nil;
            [self setHttpCache:responseObject url:url parameters:parameters];
        }];
        
    }else if (cachePolicy == HJCachePolicyCacheElseNetwork){
        //先从缓存读取数据，如果没有再从网络获取
        [self httpCacheForURL:url parameters:parameters withBlock:^(id<NSCoding> object) {
            if (object) {
                callback ? callback(object, YES, nil) : nil;
            }else{
                [self httpWithMethod:method url:url parameters:parameters headers:headers callback:^(id responseObject, BOOL isCache, NSError *error) {
                    callback ? callback(responseObject, NO, error) : nil;
                }];
            }
        }];
    }else if (cachePolicy == HJCachePolicyNetworkElseCache){
        //先从网络获取数据，如果没有，此处的没有可以理解为访问网络失败，再从缓存读取
        [self httpWithMethod:method url:url parameters:parameters headers:headers callback:^(id responseObject, BOOL isCache, NSError *error) {
            if (responseObject && !error) {
                callback ? callback(responseObject, NO, error) : nil;
                [self setHttpCache:responseObject url:url parameters:parameters];
            }else{
                [self httpCacheForURL:url parameters:parameters withBlock:^(id<NSCoding> object) {
                    callback ? callback(object, YES, nil) : nil;
                }];
            }
        }];
    }else if (cachePolicy == HJCachePolicyCacheThenNetwork){
        //先从缓存读取数据，然后在本地缓存数据，无论结果如何都会再次从网络获取数据，在这种情况下，Block将产生两次调用
        [self httpCacheForURL:url parameters:parameters withBlock:^(id<NSCoding> object) {
            callback ? callback(object, YES, nil) : nil;
            [self httpWithMethod:method url:url parameters:parameters headers:headers callback:^(id responseObject, BOOL isCache, NSError *error) {
                callback ? callback(responseObject, NO, error) : nil;
                [self setHttpCache:responseObject url:url parameters:parameters];
            }];
        }];
    }else{
        //缓存策略错误，将采取 HJCachePolicyIgnoreCache 策略
        ATLog(@"缓存策略错误");
        [self httpWithMethod:method url:url parameters:parameters headers:headers callback:callback];
    }
}
+ (void)HTTPWithMethod:(HJRequestMethod)method url:(NSString *)url parameters:(NSDictionary *)parameters cachePolicy:(HJCachePolicy)cachePolicy callback:(HJHttpRequest)callback kDEPRECATED_MSG_ATTRIBUTE("推荐使用带headers的方法");
{
    [self HTTPWithMethod:method url:url parameters:parameters headers:[_sessionManager.requestSerializer HTTPRequestHeaders] cachePolicy:cachePolicy callback:callback];
}


#pragma mark -- 网络请求处理
+(void)httpWithMethod:(HJRequestMethod)method
                  url:(NSString *)url
           parameters:(NSDictionary *)parameters
              headers:(NSDictionary *)headers
             callback:(HJHttpRequest)callback
{
    [self dataTaskWithHTTPMethod:method url:url parameters:parameters headers:headers callback:^(NSURLSessionDataTask * _Nonnull task, id _Nullable responseObject) {
        if (_logEnabled) {
            ATLog(@"请求结果 = %@",[self jsonToString:responseObject]);
        }
        [[self allSessionTask] removeObject:task];
        callback ? callback(responseObject, NO, nil) : nil;
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        if (_logEnabled) {
            ATLog(@"错误内容 = %@",error);
        }
        callback ? callback(nil, NO, error) : nil;
        [[self allSessionTask] removeObject:task];
    }];
}

+(void)dataTaskWithHTTPMethod:(HJRequestMethod)method
                          url:(NSString *)url
                   parameters:(NSDictionary *)parameters
                      headers:(NSDictionary *)headers
                     callback:(void (^)(NSURLSessionDataTask * _Nonnull, id _Nullable))callback
                      failure:(void (^)(NSURLSessionDataTask * _Nullable, NSError * _Nonnull))failure
{
    NSURLSessionTask *sessionTask;
    if (method == HJRequestMethodGET){
        sessionTask = [_sessionManager GET:url parameters:parameters headers:headers progress:nil success:callback failure:failure];
    }else if (method == HJRequestMethodPOST) {
        sessionTask = [_sessionManager POST:url parameters:parameters headers:headers progress:nil success:callback failure:failure];
    }else if (method == HJRequestMethodHEAD) {
        sessionTask = [_sessionManager HEAD:url parameters:parameters headers:headers success:^(NSURLSessionDataTask * _Nonnull task) {
            callback ? callback(task, nil) : nil;
        } failure:failure];
    }else if (method == HJRequestMethodPUT) {
        sessionTask = [_sessionManager PUT:url parameters:parameters headers:headers success:callback failure:failure];
    }else if (method == HJRequestMethodPATCH) {
        sessionTask = [_sessionManager PATCH:url parameters:parameters headers:headers success:callback failure:failure];
    }else if (method == HJRequestMethodDELETE) {
        sessionTask = [_sessionManager DELETE:url parameters:parameters headers:headers success:callback failure:failure];
    }
    //添加最新的sessionTask到数组
    sessionTask ? [[self allSessionTask] addObject:sessionTask] : nil;
}


#pragma mark -- 上传文件
+ (void)uploadFileWithURL:(NSString *)url parameters:(NSDictionary *)parameters headers:(NSDictionary *)headers name:(NSString *)name filePath:(NSString *)filePath progress:(HJHttpProgress)progress callback:(HJHttpRequest)callback
{
    NSURLSessionTask *sessionTask = [_sessionManager POST:url parameters:parameters headers:headers constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
        //添加-文件
        NSError *error = nil;
        [formData appendPartWithFileURL:[NSURL URLWithString:filePath] name:name error:&error];
    } progress:^(NSProgress * _Nonnull uploadProgress) {
        //上传进度
        dispatch_sync(dispatch_get_main_queue(), ^{
            progress ? progress(uploadProgress) : nil;
        });
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
        [[self allSessionTask] removeObject:task];
        callback ? callback(responseObject, NO, nil) : nil;
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        
        [[self allSessionTask] removeObject:task];
        callback ? callback(nil, NO, error) : nil;
    }];
    //添加最新的sessionTask到数组
    sessionTask ? [[self allSessionTask] addObject:sessionTask] : nil;
}
///不推荐使用
+ (void)uploadFileWithURL:(NSString *)url parameters:(NSDictionary *)parameters name:(NSString *)name filePath:(NSString *)filePath progress:(HJHttpProgress)progress callback:(HJHttpRequest)callback
{
    [self uploadFileWithURL:url parameters:parameters headers:[_sessionManager.requestSerializer HTTPRequestHeaders] name:name filePath:filePath progress:progress callback:callback];
}

#pragma mark -- 上传图片文件
+ (void)uploadImageURL:(NSString *)url
            parameters:(NSDictionary *)parameters
               headers:(NSDictionary *)headers
                images:(NSArray<UIImage *> *)images
                  name:(NSString *)name
              fileName:(NSString *)fileName
              mimeType:(NSString *)mimeType
              progress:(HJHttpProgress)progress
              callback:(HJHttpRequest)callback;
{
    NSURLSessionTask *sessionTask = [_sessionManager POST:url parameters:parameters headers:headers constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
        //压缩-添加-上传图片
        [images enumerateObjectsUsingBlock:^(UIImage * _Nonnull image, NSUInteger idx, BOOL * _Nonnull stop) {
            NSData *imageData = UIImageJPEGRepresentation(image, 0.5);
            [formData appendPartWithFileData:imageData name:name fileName:[NSString stringWithFormat:@"%@%lu.%@",fileName,(unsigned long)idx,mimeType ? mimeType : @"jpeg"] mimeType:[NSString stringWithFormat:@"image/%@",mimeType ? mimeType : @"jpeg"]];
        }];
        
    } progress:^(NSProgress * _Nonnull uploadProgress) {
        //上传进度
        dispatch_sync(dispatch_get_main_queue(), ^{
            progress ? progress(uploadProgress) : nil;
        });
    } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
        [[self allSessionTask] removeObject:task];
        callback ? callback(responseObject, NO, nil) : nil;
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        
        [[self allSessionTask] removeObject:task];
        callback ? callback(nil, NO, error) : nil;
    }];
    //添加最新的sessionTask到数组
    sessionTask ? [[self allSessionTask] addObject:sessionTask] : nil;
}
///不推荐使用
+ (void)uploadImageURL:(NSString *)url parameters:(NSDictionary *)parameters images:(NSArray<UIImage *> *)images name:(NSString *)name fileName:(NSString *)fileName mimeType:(NSString *)mimeType progress:(HJHttpProgress)progress callback:(HJHttpRequest)callback
{
    [self uploadImageURL:url parameters:parameters headers:[_sessionManager.requestSerializer HTTPRequestHeaders] images:images name:name fileName:fileName mimeType:mimeType progress:progress callback:callback];
}
#pragma mark -- 下载文件
+ (void)downloadWithURL:(NSString *)url fileDir:(NSString *)fileDir progress:(HJHttpProgress)progress callback:(HJHttpDownload)callback
{
    if (!fileDir.length) {
        if (_logEnabled) {
            ATLog(@"下载路径为空，使用默认目录");
        }
        NSString *documents = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
        fileDir = [documents stringByAppendingPathComponent:@"HJDownloader"];
    }

    NSString *fileName = url.lastPathComponent;
    NSString *savePath = [fileDir stringByAppendingPathComponent:fileName];

    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL fileExists = [fileManager fileExistsAtPath:savePath];
    if (fileExists) {//文件已下载，直接返回
        if (_logEnabled) {
            ATLog(@"文件已下载，直接返回");
        }
        callback ? callback(savePath, nil) : nil;
        return;
    }
    
    BOOL folderExists = [fileManager fileExistsAtPath:fileDir];
    NSError *directoryCreateError = nil;
    if (!folderExists) {//文件夹不存在，创建目录
        if (_logEnabled) {
            ATLog(@"文件夹不存在，创建目录");
        }
        [fileManager createDirectoryAtPath:fileDir withIntermediateDirectories:YES attributes:nil error:&directoryCreateError];
    }
    if (directoryCreateError) {
        callback ? callback(nil, directoryCreateError) : nil;
        return;
    }

    //创建请求对象
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
    //下载任务
    __block NSURLSessionDownloadTask *downloadTask = [_sessionManager downloadTaskWithRequest:request progress:^(NSProgress * _Nonnull downloadProgress) {
        // 下载进度
        if (_logEnabled) {
            ATLog(@"下载进度:%.2f%%",100.0*downloadProgress.completedUnitCount / downloadProgress.totalUnitCount);
        }
        dispatch_sync(dispatch_get_main_queue(), ^{
            progress ? progress(downloadProgress) : nil;
        });
    } destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
        // 设置下载路径,通过沙盒获取缓存地址,最后返回NSURL对象
        return [NSURL fileURLWithPath:savePath]; // 返回的是文件存放在本地沙盒的地址
    } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
        // 下载完成调用的方法
        [[self allSessionTask] removeObject:downloadTask];
        if (callback && error) {
            callback ? callback(nil, error) : nil;
            return;
        }
        callback ? callback(filePath.absoluteString, nil) : nil;
    }];
    
    //启动下载任务
    [downloadTask resume];
    //添加sessionTask到数组
    downloadTask ? [[self allSessionTask] addObject:downloadTask] : nil;
}

+ (NSString *)getMethodStr:(HJRequestMethod)method{
    switch (method) {
        case HJRequestMethodGET:
            return @"GET";
            break;
        case HJRequestMethodPOST:
            return @"POST";
            break;
        case HJRequestMethodHEAD:
            return @"HEAD";
            break;
        case HJRequestMethodPUT:
            return @"PUT";
            break;
        case HJRequestMethodPATCH:
            return @"PATCH";
            break;
        case HJRequestMethodDELETE:
            return @"DELETE";
            break;
            
        default:
            break;
    }
}

#pragma mark -- 网络缓存
+ (YYCache *)getYYCache
{
    return _dataCache;
}

+ (void)setHttpCache:(id)httpData url:(NSString *)url parameters:(NSDictionary *)parameters
{
    if (httpData) {
        NSString *cacheKey = [self cacheKeyWithURL:url parameters:parameters];
        [_dataCache setObject:httpData forKey:cacheKey withBlock:nil];
    }
}

+ (void)httpCacheForURL:(NSString *)url parameters:(NSDictionary *)parameters withBlock:(void(^)(id responseObject))block
{
    NSString *cacheKey = [self cacheKeyWithURL:url parameters:parameters];
    [_dataCache objectForKey:cacheKey withBlock:^(NSString * _Nonnull key, id<NSCoding>  _Nonnull object) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (_logEnabled) {
                ATLog(@"缓存结果 = %@",[self jsonToString:object]);
            }
            block(object);
        });
    }];
}


+ (void)setCostLimit:(NSInteger)costLimit
{
    [_dataCache.diskCache setCostLimit:costLimit];//磁盘最大缓存开销
}

+ (NSInteger)getAllHttpCacheSize
{
    return [_dataCache.diskCache totalCost];
}

+ (void)getAllHttpCacheSizeBlock:(void(^)(NSInteger totalCount))block
{
    return [_dataCache.diskCache totalCountWithBlock:block];
}

+ (void)removeAllHttpCache
{
    [_dataCache.diskCache removeAllObjects];
}

+ (void)removeAllHttpCacheBlock:(void(^)(int removedCount, int totalCount))progress
                       endBlock:(void(^)(BOOL error))end
{
    [_dataCache.diskCache removeAllObjectsWithProgressBlock:progress endBlock:end];
}

+ (NSString *)cacheKeyWithURL:(NSString *)url parameters:(NSDictionary *)parameters
{
    if(!parameters){return url;};
    
    if (_filtrationCacheKey.count) {
        NSMutableDictionary *mutableParameters = [NSMutableDictionary dictionaryWithDictionary:parameters];
        [mutableParameters removeObjectsForKeys:_filtrationCacheKey];
        parameters =  [mutableParameters copy];
    }

    
    // 将参数字典转换成字符串
    NSData *stringData = [NSJSONSerialization dataWithJSONObject:parameters options:0 error:nil];
    NSString *paraString = [[NSString alloc] initWithData:stringData encoding:NSUTF8StringEncoding];
    
    // 将URL与转换好的参数字符串拼接在一起,成为最终存储的KEY值
    NSString *cacheKey = [NSString stringWithFormat:@"%@%@",url,paraString];
    
    return [self md5StringFromString:cacheKey];
}

/*MD5加密URL*/
+ (NSString *)md5StringFromString:(NSString *)string {
    NSParameterAssert(string != nil && [string length] > 0);
    
    const char *value = [string UTF8String];
    
    unsigned char outputBuffer[CC_MD5_DIGEST_LENGTH];
    CC_MD5(value, (CC_LONG)strlen(value), outputBuffer);
    
    NSMutableString *outputString = [[NSMutableString alloc] initWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for(NSInteger count = 0; count < CC_MD5_DIGEST_LENGTH; count++){
        [outputString appendFormat:@"%02x",outputBuffer[count]];
    }
    
    return outputString;
}


/*json转字符串*/
+ (NSString *)jsonToString:(id)data
{
    if(!data){ return @"空"; }
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:data options:NSJSONWritingPrettyPrinted error:nil];
    return [[NSString alloc]initWithData:jsonData encoding:NSUTF8StringEncoding];
}


/************************************重置AFHTTPSessionManager相关属性**************/
#pragma mark -- 重置AFHTTPSessionManager相关属性

+ (AFHTTPSessionManager *)getAFHTTPSessionManager
{
    return _sessionManager;
}

+ (void)setRequestSerializer:(HJRequestSerializer)requestSerializer{
    _sessionManager.requestSerializer = requestSerializer==HJRequestSerializerHTTP ? [AFHTTPRequestSerializer serializer] : [AFJSONRequestSerializer serializer];
}

+ (void)setResponseSerializer:(HJResponseSerializer)responseSerializer{
    _sessionManager.responseSerializer = responseSerializer==HJResponseSerializerHTTP ? [AFHTTPResponseSerializer serializer] : [AFJSONResponseSerializer serializer];
}


+ (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field{
    [_sessionManager.requestSerializer setValue:value forHTTPHeaderField:field];
}


+ (void)setSecurityPolicyWithCerPath:(NSString *)cerPath validatesDomainName:(BOOL)validatesDomainName{
    
    NSData *cerData = [NSData dataWithContentsOfFile:cerPath];
    //使用证书验证模式
    AFSecurityPolicy *securitypolicy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeCertificate];
    //如果需要验证自建证书(无效证书)，需要设置为YES
    securitypolicy.allowInvalidCertificates = YES;
    //是否需要验证域名，默认为YES
    securitypolicy.validatesDomainName = validatesDomainName;
    securitypolicy.pinnedCertificates = [[NSSet alloc]initWithObjects:cerData, nil];
    [_sessionManager setSecurityPolicy:securitypolicy];
}

@end


#pragma mark -- NSDictionary,NSArray的分类
/*
 ************************************************************************************
 *新建NSDictionary与NSArray的分类, 控制台打印json数据中的中文
 ************************************************************************************
 */
//#ifdef DEBUG
@implementation NSArray (AT)

- (NSString *)descriptionWithLocale:(id)locale{
    
    NSMutableString *strM = [NSMutableString stringWithString:@"(\n"];
    [self enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [strM appendFormat:@"\t%@,\n",obj];
    }];
    [strM appendString:@")\n"];
    return  strM;
}
@end

@implementation NSDictionary (AT)

- (NSString *)descriptionWithLocale:(id)locale{
    
    NSMutableString *strM = [NSMutableString stringWithString:@"{\n"];
    [self enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        [strM appendFormat:@"\t%@,\n",obj];
    }];
    [strM appendString:@"}\n"];
    return  strM;
}

@end
