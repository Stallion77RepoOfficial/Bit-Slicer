/*
 * Copyright (c) 2012 Mayur Pawashe
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * Redistributions of source code must retain the above copyright notice,
 * this list of conditions and the following disclaimer.
 *
 * Redistributions in binary form must reproduce the above copyright
 * notice, this list of conditions and the following disclaimer in the
 * documentation and/or other materials provided with the distribution.
 *
 * Neither the name of the project's author nor the names of its
 * contributors may be used to endorse or promote products derived from
 * this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
 * "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
 * LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS
 * FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
 * HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
 * SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
 * TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import <Cocoa/Cocoa.h>
#import "ZGProcessTypes.h"

NS_ASSUME_NONNULL_BEGIN

@interface ZGRunningProcess : NSObject

- (id)initWithProcessIdentifier:(pid_t)processIdentifier type:(ZGProcessType)processType translated:(BOOL)translated internalName:(nullable NSString *)name;
- (id)initWithProcessIdentifier:(pid_t)processIdentifier;

- (void)invalidateAppInfoCache;

@property (readonly, nonatomic) pid_t processIdentifier;
@property (readonly, nonatomic, copy) NSString *internalName;
@property (readonly, nonatomic, nullable) NSString *name;
@property (readonly, nonatomic, nullable) NSImage *icon;
@property (readonly, nonatomic, nullable) NSURL *fileURL;
@property (readonly, nonatomic) ZGProcessType type;
@property (readonly, nonatomic) BOOL translated;
@property (readonly, nonatomic) BOOL isGame;
@property (readonly, nonatomic) BOOL isThirdParty;
@property (readonly, nonatomic) BOOL isWebContent;
@property (readonly, nonatomic) BOOL hasHelpers;
@property (readonly, nonatomic) NSApplicationActivationPolicy activationPolicy;

@end

NS_ASSUME_NONNULL_END
