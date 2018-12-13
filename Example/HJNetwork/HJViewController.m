//
//  HJViewController.m
//  HJNetwork
//
//  Created by Johnny on 04/19/2018.
//  Copyright (c) 2018 Johnny. All rights reserved.
//

#import "HJViewController.h"
#import "HJNetwork.h"

@interface HJViewController ()
@property (weak, nonatomic) IBOutlet UITextField *urlTextField;
@property (weak, nonatomic) IBOutlet UITextView *responseTextView;
@property (weak, nonatomic) IBOutlet UILabel *stateLabel;
@property (weak, nonatomic) IBOutlet UILabel *cacheLabel;
@property (weak, nonatomic) IBOutlet UIButton *requestBtn;

@end

@implementation HJViewController
{
    HJCachePolicy cachePolicy;
    HJRequestMethod method;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    NSLog(@"---->%@",NSHomeDirectory());
    //DEMO 默认GET请求
    method = HJRequestMethodGET;
    
    //开启控制台log
    [HJNetwork setLogEnabled:YES];
//    [HJNetwork setBaseURL:@"https://atime.com/app/v1/"];
//    [HJNetwork setFiltrationCacheKey:@[@"time",@"ts"]];
    [HJNetwork setRequestTimeoutInterval:60.0f];
    
    //按App版本号缓存网络请求内容 可修改版本号查看效果 或 使用自定义版本号方法
    [HJNetwork setCacheVersionEnabled:NO];
    
    //网络状态
    __weak __typeof(&*self)weakSelf = self;
    [HJNetwork getNetworkStatusWithBlock:^(HJNetworkStatusType status) {
        weakSelf.stateLabel.text = [NSString stringWithFormat:@"当前网络:%@",[weakSelf getStateStr:status]];
    }];
    
    //演示请求
    [self request:_requestBtn];
//    [HJNetwork downloadWithURL:@"http://sw.bos.baidu.com/sw-search-sp/software/de4fe04c2280e/SogouInput_mac_4.0.0.3127.dmg" fileDir:[self createDefaultPath] progress:^(NSProgress *progress) {
//        NSLog(@"--->%lld",progress.completedUnitCount);
//    } callback:^(NSString *path, NSError *error) {
//        NSLog(@"--->%@",path);
//    }];
    
    [self downloadWithURLs:@[@"http://sw.bos.baidu.com/sw-search-sp/software/de4fe04c2280e/SogouInput_mac_4.0.0.3127.dmg",@"https://dldir1.qq.com/qqfile/QQforMac/QQ_V6.5.2.dmg",@"https://dldir1.qq.com/music/clntupate/mac/QQMusicMac_Mgr.dmg",@"https://dldir1.qq.com/invc/tt/QQBrowser_for_Mac.dmg",@"https://dldir1.qq.com/weixin/mac/WeChat_2.3.17.18.dmg"] fileDir:[self createDefaultPath] progress:^(NSProgress *progress) {

    } callback:^(NSString *path, NSError *error) {

    }];
    
}

- (void)downloadWithURLs:(NSArray *)urls fileDir:(NSString *)fileDir progress:(HJHttpProgress)progressBlock callback:(HJHttpDownload)callback
{
    
    NSProgress *downloadProgress = [NSProgress currentProgress];
    
    for (int i = 0; i < urls.count; i ++) {
        [HJNetwork downloadWithURL:urls[i] fileDir:fileDir progress:^(NSProgress *progress) {
            downloadProgress.totalUnitCount += progress.totalUnitCount;
            downloadProgress.completedUnitCount = ( downloadProgress.completedUnitCount)/urls.count;

            NSLog(@"下载进度:%.2f%%",100.0*downloadProgress.completedUnitCount / downloadProgress.totalUnitCount);
            
            if (progressBlock) {
                progressBlock(downloadProgress);
            }
        } callback:callback];
    }
}

- (NSString *)createDefaultPath {
    NSString *documents = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSString *downloadFolder = [documents stringByAppendingPathComponent:@"downloader"];
    [self handleDownloadFolder:downloadFolder];
    return downloadFolder;
}

/**
 处理下载文件夹
 - 确保文件夹存在
 - 为此文件夹设置备份属性，避免占用用户iCloud容量，不然会被拒的
 @param folder 文件路径
 */
- (void)handleDownloadFolder:(NSString *)folder {
    BOOL isDir = NO;
    BOOL folderExist = [[NSFileManager defaultManager] fileExistsAtPath:folder isDirectory:&isDir];
    if (!folderExist || !isDir ) {
        [[NSFileManager defaultManager] createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
        NSURL *fileURL = [NSURL fileURLWithPath:folder];
        [fileURL setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:nil];
    }
}


/**修改缓存策略*/
- (IBAction)changeCachePolicy:(UISegmentedControl *)sender {
    cachePolicy = sender.selectedSegmentIndex;
    _cacheLabel.text = [self getCacheStr:cachePolicy];
}

/**修改请求方法*/
- (IBAction)changeMethod:(UISegmentedControl *)sender {
    method = sender.selectedSegmentIndex;
}

/**请求*/
- (IBAction)request:(UIButton *)sender {
    sender.enabled = NO;
    __weak __typeof(&*self)weakSelf = self;
    [HJNetwork HTTPWithMethod:method url:_urlTextField.text parameters:nil cachePolicy:cachePolicy callback:^(id responseObject, BOOL isCache, NSError *error) {
        sender.enabled = YES;
        if (!error) {
            weakSelf.responseTextView.text = [NSString stringWithFormat:@"%@",responseObject];
        }else{
            weakSelf.responseTextView.text = [error localizedDescription];
            NSLog(@"---->%@",@"错误");
        }
    }];
}

/**取消请求*/
- (IBAction)cancelRequest:(UIButton *)sender {
    [HJNetwork cancelRequestWithURL:_urlTextField.text];
    _requestBtn.enabled = YES;
}

/**清空*/
- (IBAction)empty:(UIButton *)sender {
    _responseTextView.text = @"";
}

/**清除缓存*/
- (IBAction)clearRequest:(UIButton *)sender {
    sender.enabled = NO;
    [HJNetwork removeAllHttpCacheBlock:nil endBlock:^(BOOL error) {
        //通知主线程刷新
        dispatch_async(dispatch_get_main_queue(), ^{
            sender.enabled = YES;
        });
    }];
}


/**获取网络状态*/
- (NSString *)getStateStr:(HJNetworkStatusType)status
{
    switch (status) {
        case HJNetworkStatusUnknown:
            return @"未知网络";
            break;
        case HJNetworkStatusNotReachable:
            return @"无网路";
            break;
        case HJNetworkStatusReachableWWAN:
            return @"手机网络";
            break;
        case HJNetworkStatusReachableWiFi:
            return @"WiFi网络";
            break;
        default:
            break;
    }
}

/**获取网络状态*/
- (NSString *)getCacheStr:(HJCachePolicy)cache
{
    switch (cache) {
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
            return @"先从网络获取数据，如果没有再从缓存读取数据，此处的没有可以理解为访问网络失败，再从缓存读取数据";
            break;
        case HJCachePolicyCacheThenNetwork:
            return @"先从缓存读取数据，然后在从网络获取并且缓存，Block将产生两次调用";
            break;
        default:
            break;
    }
}



- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [self.view endEditing:YES];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
