//
//  ViewController.m
//  MyServer
//
//  Created by gongwenkai on 2017/1/16.
//  Copyright © 2017年 gongwenkai. All rights reserved.
//

#import "ViewController.h"

#include <netinet/in.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#import "ClientModel.h"
static int const kMaxConnectCount = 5;

@interface ViewController()
@property (weak) IBOutlet NSTextField *textField;
//@property (nonatomic,assign)int client_socket; //客户端socket
@property (unsafe_unretained) IBOutlet NSTextView *textView;
    @property (nonatomic,strong)NSMutableArray *clientArray;
    @property (nonatomic,strong)NSMutableArray *clientNameArray;
@end

@implementation ViewController

- (NSMutableArray *)clientArray {
    if (!_clientArray) {
        _clientArray = [NSMutableArray array];
    }
    return _clientArray;
}
- (NSMutableArray *)clientNameArray {
    if (!_clientNameArray) {
        _clientNameArray = [NSMutableArray array];
    }
    return _clientNameArray;
}
    
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    //创建socket
    int server_socket = socket(AF_INET, SOCK_STREAM, 0);
    if (server_socket == -1) {
        NSLog(@"创建失败");
        [self showLogsWithString:@"socket创建失败"];

    }else{
        //绑定地址和端口
        struct sockaddr_in server_addr;
        server_addr.sin_len = sizeof(struct sockaddr_in);
        server_addr.sin_family = AF_INET;
        server_addr.sin_port = htons(1234);
        server_addr.sin_addr.s_addr = inet_addr("127.0.0.1");
        bzero(&(server_addr.sin_zero), 8);
        
        int bind_result = bind(server_socket, (struct sockaddr*)&server_addr, sizeof(server_addr));
        if (bind_result == -1) {
            NSLog(@"绑定端口失败");
            [self showLogsWithString:@"绑定端口失败"];

        }else{
            if (listen(server_socket, kMaxConnectCount)==-1) {
                NSLog(@"监听失败");
                [self showLogsWithString:@"监听失败"];

            }else{
                for (int i = 0; i < kMaxConnectCount; i++) {
                    //接受客户端的链接
                    [self acceptClientWithServerSocket:server_socket];
                }
            }
        }
    }
}


- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

//创建线程接受客户端
-(void)acceptClientWithServerSocket:(int)server_socket{
    struct sockaddr_in client_address;
    socklen_t address_len;
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue, ^{
        //创建新的socket
        while (1) {
            int client_socket = accept(server_socket, (struct sockaddr*)&client_address,&address_len );
            if (client_socket == -1) {
                [self showLogsWithString:@"接受客户端链接失败"];
                NSLog(@"接受客户端链接失败");
            }else{
                NSString *acceptInfo = [NSString stringWithFormat:@"客户端 in,socket:%d",client_socket];
                [self showLogsWithString:acceptInfo];
                
                //接受客户端数据
                [self recvFromClinetWithSocket:client_socket];
            }
        }
    });
}

//接受客户端数据
- (void)recvFromClinetWithSocket:(int)client_socket{
    while (1) {
        //接受客户端传来的数据
        char buf[1024] = {0};
        long iReturn = recv(client_socket, buf, 1024, 0);
        if (iReturn>0) {
            NSLog(@"客户端来消息了");
            NSString *str = [NSString stringWithCString:buf encoding:NSUTF8StringEncoding];
            [self showLogsWithString:[NSString stringWithFormat:@"客户端来消息了:%@",str]];
            [self checkRecvStr:str andClientSocket:client_socket];
        }else if (iReturn == -1){
            NSLog(@"读取消息失败");
            [self showLogsWithString:@"读取消息失败"];
            break;
        }else if (iReturn == 0){
            NSLog(@"客户端走了");
            [self showLogsWithString:[NSString stringWithFormat:@"客户端 out socket:%d",client_socket]];
            NSMutableArray *array = [NSMutableArray arrayWithArray:self.clientArray];
            for (ClientModel *model in array) {
                if (model.clientSocket == client_socket) {
                    [self.clientNameArray removeObject:model.clientName];
                    [self.clientArray removeObject:model];
                }
            }
            
            close(client_socket);
            
            break;
        }
    }
}
    
    //检查接受到的字符串
- (void)checkRecvStr:(NSString*)str andClientSocket:(int)socket{
    if ([str hasPrefix:@"name:"]) {
        NSString *name = [str substringFromIndex:5];
        
        ClientModel *model = [[ClientModel alloc] init];
        model.clientSocket = socket;
        model.clientName = name;

        
        if (self.clientArray.count > 0) {
            int flag = 999;
            //用户名不能相同
            int i = 0;

            for (ClientModel *client in self.clientArray) {
                
                //改名
                if (client.clientSocket == socket) {
                    NSString *oldName = self.clientNameArray[i];
                    self.clientNameArray[i] = name;
                    self.clientArray[i] = model;

                    for (ClientModel *oldclient in self.clientArray) {
                        [self sendMsg:[NSString stringWithFormat:@"%@ 改名 %@",oldName,name] toClient:oldclient.clientSocket];
                        [self showLogsWithString:[NSString stringWithFormat:@"%@ 改名 %@",oldName,name]];
                        NSString *list = [self.clientNameArray componentsJoinedByString:@","];
                        //向客户端推送当前在线列表
                        [self sendMsg:[NSString stringWithFormat:@"list:%@",list] toClient:oldclient.clientSocket];
                    }
                    
                    flag = 2;
                    
                }else{
                    if ([client.clientName isEqualToString:model.clientName]) {
                        //用户名已存在
                        flag = 1;
                        break;
                    }
                }
                i++;

            }
            if (flag != 1 & flag != 2) {
                [self.clientArray addObject:model];
                [self.clientNameArray addObject:model.clientName];
                //向客户端推送当前在线列表
                for (ClientModel *client in self.clientArray) {
                    [self sendMsg:[NSString stringWithFormat:@"%@,上线了",name] toClient:client.clientSocket];
                    NSString *list = [self.clientNameArray componentsJoinedByString:@","];
                    //向客户端推送当前在线列表
                    [self sendMsg:[NSString stringWithFormat:@"list:%@",list] toClient:client.clientSocket];
                }
                
                //给当前客户端发送一条欢迎信息
                NSString *msg = [NSString stringWithFormat:@"Welcome %@ !",name];
                [self sendMsg:msg toClient:socket];
                [self showLogsWithString:msg];

            }else if (flag == 1){
                [self sendMsg:@"注册用户名失败，用户名已经存在，请重新设置用户名" toClient:socket];
                [self showLogsWithString:[NSString stringWithFormat:@"socket %d 注册用户名失败，设置的用户名已经存在",socket]];
                
                for (ClientModel *model in self.clientArray) {
                    
                    [name isEqualToString:model.clientName];
                }
                
                

            }
        }else{
            [self.clientArray addObject:model];
            [self.clientNameArray addObject:model.clientName];
            //向客户端推送当前在线列表
            //给当前客户端发送一条欢迎信息
            NSString *msg = [NSString stringWithFormat:@"Welcome %@ !",name];
            [self sendMsg:msg toClient:socket];
            [self showLogsWithString:msg];
            
            NSString *list = [self.clientNameArray componentsJoinedByString:@","];
            //向客户端推送当前在线列表
            [self sendMsg:[NSString stringWithFormat:@"list:%@",list] toClient:socket];
            
        }
    
    }
    //给某人发消息
    else if  ([str hasPrefix:@"to:"]){
        NSRange nameRange = [str rangeOfString:@"*"];
        NSString *name = [str substringWithRange:NSMakeRange(3, nameRange.location-3)];
        NSString *content = [str substringFromIndex:nameRange.location+1];
        NSString *fromClientName;
        //找出发送者
        for (ClientModel *model in self.clientArray) {
            if (socket == model.clientSocket) {
                fromClientName = model.clientName;
                break;
            }
        }
        
        //给目标发送信息
        for (ClientModel *model in self.clientArray) {
            if ([name isEqualToString:model.clientName]) {
                NSString *msg = [NSString stringWithFormat:@"%@ to you\n%@",fromClientName,content];
                [self sendMsg:msg toClient:model.clientSocket];
                
                [self showLogsWithString:[NSString stringWithFormat:@"%@ 发送给 %@ 内容是：%@",fromClientName,name,content]];
                break;
                
            }
        }
        
    }
}
    
//给客户端发送信息
- (void)sendMsg:(NSString*)msg toClient:(int)socket{
    char *buf[1024] = {0};
    const char *p1 = (char*)buf;
    p1 = [msg cStringUsingEncoding:NSUTF8StringEncoding];
    send(socket, p1, 1024, 0);
}

    //在界面上显示日志
- (void)showLogsWithString:(NSString*)str {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *newStr = [NSString stringWithFormat:@"\n%@",str];
        self.textView.string = [self.textView.string stringByAppendingString:newStr];
    });
}
    
@end
