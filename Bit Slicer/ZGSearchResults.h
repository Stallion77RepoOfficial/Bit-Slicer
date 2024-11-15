/*
 * Copyright (c) 2013 Mayur Pawashe
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

#import <Foundation/Foundation.h>
#import "ZGMemoryTypes.h"
#import "ZGVariableTypes.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, ZGSearchResultType)
{
	ZGSearchResultTypeDirect = 0,
	ZGSearchResultTypeIndirect
};

@interface ZGSearchResults : NSObject

@property (nonatomic, readonly) ZGMemorySize count;

@property (nonatomic, readonly) ZGMemorySize stride;
@property (nonatomic, readonly) BOOL unalignedAccess;
@property (nonatomic, readonly) NSArray<NSData *> *resultSets;
@property (nonatomic, readonly) ZGSearchResultType resultType;
@property (nonatomic) uint16_t indirectMaxLevels;

@property (nonatomic, nullable) NSArray<NSValue *> *totalStaticSegmentRanges;
@property (nonatomic, nullable) NSArray<NSNumber *> *headerAddresses;
@property (nonatomic, nullable) NSArray<NSString *> *filePaths;

// Only used by clients
@property (nonatomic, readonly) ZGVariableType dataType;

typedef void (^zg_enumerate_search_results_t)(const void *data, BOOL *stop);

+ (ZGMemorySize)indirectStrideWithMaxNumberOfLevels:(ZGMemorySize)maxNumberOfLevels pointerSize:(ZGMemorySize)pointerSize;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithResultSets:(NSArray<NSData *> *)resultSets resultType:(ZGSearchResultType)resultType dataType:(ZGVariableType)dataType stride:(ZGMemorySize)stride unalignedAccess:(BOOL)unalignedAccess;

- (instancetype)indirectSearchResultsByAppendingIndirectSearchResults:(ZGSearchResults *)newSearchResults;

- (void)enumerateWithCount:(ZGMemorySize)count removeResults:(BOOL)removeResults usingBlock:(zg_enumerate_search_results_t)addressCallback;

- (void)updateHeaderAddresses:(NSArray<NSNumber *> *)headerAddresses totalStaticSegmentRanges:(NSArray<NSValue *> *)totalStaticSegmentRanges usingFilePaths:(NSArray<NSString *> *)filePaths;

@end

NS_ASSUME_NONNULL_END
