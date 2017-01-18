//
//  ViewController.m
//  MyClient
//
//  Created by gongwenkai on 2017/1/16.
//  Copyright © 2017年 gongwenkai. All rights reserved.
//

#import "ViewController.h"
#include <netinet/in.h>
#include <sys/socket.h>
#include <arpa/inet.h>
@interface ViewController ()<UITableViewDelegate,UITableViewDataSource>
//服务器socket
@property (nonatomic,assign)int server_socket;

//UI
@property (weak, nonatomic) IBOutlet UITextField *userNameField;
@property (weak, nonatomic) IBOutlet UITextView *chatView;
@property (weak, nonatomic) IBOutlet UITextField *msgField;
@property (weak, nonatomic) IBOutlet UILabel *toName;
@property (weak, nonatomic) IBOutlet UIView *onlineUserView;
@property (nonatomic,strong)UITableView *onlineTable;

//user列表
@property (nonatomic,strong)NSMutableArray *userArray;

@end

@implementation ViewController
- (NSMutableArray *)userArray {
    if (!_userArray) {
        _userArray = [NSMutableArray array];
    }
    return _userArray;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    [self.userNameField becomeFirstResponder];
    self.userNameField.text = @"";
    self.msgField.text = @"";
    //添加table用户列表
    self.onlineTable = [[UITableView alloc] initWithFrame:self.onlineUserView.frame style:UITableViewStylePlain];
    self.onlineTable.delegate = self;
    self.onlineTable.dataSource = self;
    [self.view addSubview:self.onlineTable];
    
    int server_socket = socket(AF_INET, SOCK_STREAM, 0);
    if (server_socket == -1) {
        NSLog(@"创建失败");
    }else{
        //绑定地址和端口
        struct sockaddr_in server_addr;
        server_addr.sin_len = sizeof(struct sockaddr_in);
        server_addr.sin_family = AF_INET;
        server_addr.sin_port = htons(1234);
        server_addr.sin_addr.s_addr = inet_addr("127.0.0.1");
        bzero(&(server_addr.sin_zero), 8);
        
        //接受客户端的链接
        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        dispatch_async(queue, ^{
            //创建新的socket
            int aResult = connect(server_socket, (struct sockaddr*)&server_addr, sizeof(struct sockaddr_in));
            if (aResult == -1) {
                NSLog(@"链接失败");
            }else{
                self.server_socket = server_socket;
                [self acceptFromServer];
            }
        });
    }
}

//从服务端接受消息
- (void)acceptFromServer{
    while (1) {
        //接受服务器传来的数据
        char buf[1024];
        long iReturn = recv(self.server_socket, buf, 1024, 0);
        if (iReturn>0) {
            NSString *str = [NSString stringWithCString:buf encoding:NSUTF8StringEncoding];

            //筛选前缀
            if ([str hasPrefix:@"list:"]) {
                NSString *arrayStr = [str substringFromIndex:5];
                NSArray *list = [arrayStr componentsSeparatedByString:@","];
                self.userArray = [NSMutableArray arrayWithArray:list];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.onlineTable reloadData];
                });
                NSLog(@"当前在线用户列表：%@",arrayStr);
            }else{
                //回到主线程 界面上显示内容
                [self showLogsWithString:str];
            }
             
        }else if (iReturn == -1){
            NSLog(@"接受失败-1");
            break;
        }
    }
}
    
    
//在界面上显示日志
- (void)showLogsWithString:(NSString*)str {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *newStr = [NSString stringWithFormat:@"\n%@",str];
        self.chatView.text = [self.chatView.text stringByAppendingString:newStr];
    });
}
    
    
- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

//设置用户名
- (IBAction)clickSetUserName:(id)sender {
    NSString *msg = [NSString stringWithFormat:@"name:%@",self.userNameField.text] ;
    [self sendMsg:msg];
//    [self showLogsWithString:msg];
    [self.msgField becomeFirstResponder];
}

//发送信息
- (IBAction)clickSendMsg:(id)sender {
    
    if ([self.msgField.text isEqualToString:@""] || ![self.userArray containsObject:self.userNameField.text] || [self.toName.text isEqualToString:self.userNameField.text]) {
        [self showLogsWithString:@"请设置用户名、检查发送对象、消息不能为空"];
        return;
    }
    NSString *msg = [NSString stringWithFormat:@"to:%@*%@",self.toName.text,self.msgField.text];
    [self sendMsg:msg];
    NSString *displayMsg = [NSString stringWithFormat:@"to:%@\n%@",self.toName.text,self.msgField.text];
    [self showLogsWithString:displayMsg];
    self.msgField.text = @"";

}

    
//给客户端发送信息
- (void)sendMsg:(NSString*)msg {
    char *buf[1024] = {0};
    const char *p1 = (char*)buf;
    p1 = [msg cStringUsingEncoding:NSUTF8StringEncoding];
    send(self.server_socket, p1, 1024, 0);
}

#pragma mark - TableViewDelegate & dataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return self.userArray.count;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    static NSString *cellId = @"onlinetableviewcellid";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellId];
    }else{
        NSLog(@"cell重用了");
    }
    
    cell.textLabel.text = self.userArray[indexPath.row];
    
    
    return cell;
}
    
//点击cell
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    self.toName.text = self.userArray[indexPath.row];
    [self.msgField becomeFirstResponder];
}


@end
