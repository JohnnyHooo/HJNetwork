# HJNetwork

[![CI Status](http://img.shields.io/travis/Johnny/HJNetwork.svg?style=flat)](https://travis-ci.org/Johnny/HJNetwork)
[![Version](https://img.shields.io/cocoapods/v/HJNetwork.svg?style=flat)](http://cocoapods.org/pods/HJNetwork)
[![License](https://img.shields.io/cocoapods/l/HJNetwork.svg?style=flat)](http://cocoapods.org/pods/HJNetwork)
[![Platform](https://img.shields.io/cocoapods/p/HJNetwork.svg?style=flat)](http://cocoapods.org/pods/HJNetwork)

- HJNetwork 对 AFHTTPSessionManager 进行二次封装。包括网络请求、文件上传、文件下载这三个方法。并且支持RESTful API GET、POST、PUT、DELETE、PATCH的请求。同时使用YYCache做了强大的缓存策略。

- 拥有 AFNetwork 大部分常用功能，包括网络状态监听等，提供类方法和实例方法调用。

- 非常好的扩展性，开放出了YYCache和AFNetwork的实例对象，更便于满足各种不同需求。

- 支持多种缓存策略。



## 安装

### 支持 Cocoapods 安装

```ruby
pod 'HJNetwork'
```
## 使用

所有方法都可以直接看 HJNetworking.h 中的声明以及注释。

### HJNetwork 配置

#### 设置请求根路径

```objc
[HJNetwork setBaseURL:@"https://atime.com/app/v1/"];
```
baseURL 的路径一定要有“/”结尾，设置后所有的网络访问都使用相对路径。

#### 设置日志

##### 日志打印的开关

```objc
[HJNetwork setLogEnabled:YES];
```
### 网络请求

#### 常规调用

**以 POST 方法为例，方法定义：**

```objc
/**
 POST请求
 
 @param url 请求地址
 @param parameters 请求参数
 @param cachePolicy 缓存策略
 @param success 请求回调
 */
+ (void)POSTWithURL:(NSString *)url
         parameters:(NSDictionary *)parameters
        cachePolicy:(HJCachePolicy)cachePolicy
            success:(HJHttpRequest)success;
```
