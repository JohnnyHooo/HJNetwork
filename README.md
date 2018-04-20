# HJNetwork

[![CI Status](http://img.shields.io/travis/Johnny/HJNetwork.svg?style=flat)](https://travis-ci.org/Johnny/HJNetwork)
[![Version](https://img.shields.io/cocoapods/v/HJNetwork.svg?style=flat)](http://cocoapods.org/pods/HJNetwork)
[![License](https://img.shields.io/cocoapods/l/HJNetwork.svg?style=flat)](http://cocoapods.org/pods/HJNetwork)
[![Platform](https://img.shields.io/cocoapods/p/HJNetwork.svg?style=flat)](http://cocoapods.org/pods/HJNetwork)
## 前言
```ruby
本来是想在GitHub找一个符合自己App的网络请求库，结果就是要么不支持缓存或者不支持RESTful API 请求，
又或者带缓存的又不支持过滤某一些参数字段(否则无法得到缓存)，带着这样的需求之下就有了 “HJNetwork” 这个库。
初衷就是在最大程度下满足所有App的日常需求。
```
	
<br /> 
<img src="https://raw.githubusercontent.com/JohnnyHooo/HJNetwork/master/HJNetwork.png"  width="313" height="616"  alt="Demo效果" align=right />

## 特点
- HJNetwork 对 AFHTTPSessionManager 进行二次封装。包括网络请求、文件上传、文件下载这三个方法。并且支持RESTful API GET、POST、PUT、DELETE、PATCH的请求。同时使用YYCache做了强大的缓存策略。

- 拥有 AFNetwork 大部分常用功能，包括网络状态监听等，提供类方法和实例方法调用。

- 非常好的扩展性，开放出了YYCache和AFNetwork的实例对象，更便于满足各种不同需求。

- 支持多种缓存策略。

## 安装

### 支持 Cocoapods 安装

```ruby
pod 'HJNetwork'
```
<br /> 

## 使用
**所有方法都可以直接看 HJNetworking.h 中的声明以及注释。**

### HJNetwork 的全局配置

#### 设置请求根路径

```objc
[HJNetwork setBaseURL:@"https://atime.com/app/v1/"];
```
#### 设置缓存过滤参数key(如时间戳，随机数)否则会导致无法得到缓存数据

```objc
[HJNetwork setFiltrationCacheKey:@[@"time",@"ts"]];
```


#### 设置日志

##### 日志打印的开关

```objc
[HJNetwork setLogEnabled:YES];
```
### 网络状态

#### 网络状态监听

```objc
[HJNetwork getNetworkStatusWithBlock:^(HJNetworkStatusType status) {
        switch (status) {
            case HJNetworkStatusUnknown:
                //未知网络
                break;
            case HJNetworkStatusNotReachable:
                //无网路
                break;
            case HJNetworkStatusReachableWWAN:
                //手机网络
                break;
            case HJNetworkStatusReachableWiFi:
                //WiFi网络
                break;
            default:
                break;
        }
    }];
```
<br /> 

### 网络请求

#### 缓存策略

```objc
typedef NS_ENUM(NSUInteger, HJCachePolicy){
    /**只从网络获取数据，且数据不会缓存在本地*/
    HJCachePolicyIgnoreCache = 0,
    /**只从缓存读数据，如果缓存没有数据，返回一个空*/
    HJCachePolicyCacheOnly = 1,
    /**先从网络获取数据，同时会在本地缓存数据*/
    HJCachePolicyNetworkOnly = 2,
    /**先从缓存读取数据，如果没有再从网络获取*/
    HJCachePolicyCacheElseNetwork = 3,
    /**先从网络获取数据，如果没有，此处的没有可以理解为访问网络失败，再从缓存读取*/
    HJCachePolicyNetworkElseCache = 4,
    /**先从缓存读取数据，然后在本地缓存数据，无论结果如何都会再次从网络获取数据，在这种情况下，Block将产生两次调用*/
    HJCachePolicyCacheThenNetwork = 5
};
```
#### 请求方式
**以 POST 方法为例，方法定义：**
```objc
/**
 POST请求
 
 @param url 请求地址
 @param parameters 请求参数
 @param cachePolicy 缓存策略
 @param callback 请求回调
 */
+ (void)POSTWithURL:(NSString *)url
         parameters:(NSDictionary *)parameters
        cachePolicy:(HJCachePolicy)cachePolicy
            callback:(HJHttpRequest)callback;
```
**自定义请求方式：**
```objc
/**
 自定义请求方式
 
 @param method 请求方式(GET, POST, HEAD, PUT, PATCH, DELETE)
 @param url 请求地址
 @param parameters 请求参数
 @param cachePolicy 缓存策略
 @param callback 请求回调
 */
+ (void)HTTPWithMethod:(HJRequestMethod)method
                    url:(NSString *)url
             parameters:(NSDictionary *)parameters
            cachePolicy:(HJCachePolicy)cachePolicy
                callback:(HJHttpRequest)callback;
```
#### 取消请求

```objc
/**
 取消所有HTTP请求
 */
+ (void)cancelAllRequest;

/**
 取消指定URL的HTTP请求
 */
+ (void)cancelRequestWithURL:(NSString *)url;
```
#### 上传

```objc
/**
 上传文件
 
 @param url 请求地址
 @param parameters 请求参数
 @param name 文件对应服务器上的字段
 @param filePath 文件路径
 @param progress 上传进度
 @param callback 请求回调
 */
+ (void)uploadFileWithURL:(NSString *)url
               parameters:(NSDictionary *)parameters
                     name:(NSString *)name
                 filePath:(NSString *)filePath
                 progress:(HJHttpProgress)progress
                  callback:(HJHttpRequest)callback;
```


#### 下载

```objc
/**
 下载文件

 @param url 请求地址
 @param fileDir 文件存储的目录(默认存储目录为Download)
 @param progress 文件下载的进度信息
 @param callback 请求回调
 */
+ (void)downloadWithURL:(NSString *)url
                fileDir:(NSString *)fileDir
               progress:(HJHttpProgress)progress
                callback:(HJHttpDownload)callback;
```
<br /> 

### 缓存处理
#### 设置最大缓存内存

```objc
/**
 *  磁盘最大缓存开销大小 bytes(字节)
 */
+ (void)setCostLimit:(NSInteger)costLimit;

```
#### 获取网络缓存的总大小
```objc
/**
 *  获取网络缓存的总大小 bytes(字节)
 *  推荐使用该方法 不会阻塞主线程，通过block返回
 */
+ (void)getAllHttpCacheSizeBlock:(void(^)(NSInteger totalCount))block;

```
#### 删除所有网络缓存
```objc
/**
 *  删除所有网络缓存
 *  推荐使用该方法 不会阻塞主线程，同时返回Progress
 */
+ (void)removeAllHttpCacheBlock:(void(^)(int removedCount, int totalCount))progress
                       endBlock:(void(^)(BOOL error))end;

```

