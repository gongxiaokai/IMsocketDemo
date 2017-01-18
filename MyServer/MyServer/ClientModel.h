//
//  ClientModel.h
//  MyServer
//
//  Created by gongwenkai on 2017/1/17.
//  Copyright © 2017年 gongwenkai. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ClientModel : NSObject
    @property(nonatomic,assign)int clientSocket;
    @property(nonatomic,copy)NSString *clientName;
@end
