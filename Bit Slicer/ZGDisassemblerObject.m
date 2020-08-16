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

#import "ZGDisassemblerObject.h"
#import "ZGX86DisassemblerObject.h"
#import "ZGARM64DisassemblerObject.h"

@implementation ZGDisassemblerObject

+ (id<ZGDisassemblerObject>)disassemblerObjectWithBytes:(const void *)bytes address:(ZGMemoryAddress)address size:(ZGMemorySize)size processType:(ZGProcessType)processType
{
	id<ZGDisassemblerObject> disassemblerObject;
	if (ZG_PROCESS_TYPE_IS_X86_64(processType) || ZG_PROCESS_TYPE_IS_I386(processType))
	{
		disassemblerObject = [[ZGX86DisassemblerObject alloc] initWithBytes:bytes address:address size:size pointerSize:ZG_PROCESS_POINTER_SIZE(processType)];
	}
	else if (ZG_PROCESS_TYPE_IS_ARM64(processType))
	{
		disassemblerObject = [[ZGARM64DisassemblerObject alloc] initWithBytes:bytes address:address size:size];
	}
	assert(disassemblerObject != nil);
	
	return disassemblerObject;
}

+ (BOOL)isCallMnemonic:(int64_t)mnemonic processType:(ZGProcessType)processType
{
	if (ZG_PROCESS_TYPE_IS_X86_64(processType) || ZG_PROCESS_TYPE_IS_I386(processType))
	{
		return [ZGX86DisassemblerObject isCallMnemonic:mnemonic];
	}
	else if (ZG_PROCESS_TYPE_IS_ARM64(processType))
	{
		return [ZGARM64DisassemblerObject isCallMnemonic:mnemonic];
	}
	return NO;
}

+ (BOOL)isJumpMnemonic:(int64_t)mnemonic processType:(ZGProcessType)processType
{
	if (ZG_PROCESS_TYPE_IS_X86_64(processType) || ZG_PROCESS_TYPE_IS_I386(processType))
	{
		return [ZGX86DisassemblerObject isJumpMnemonic:mnemonic];
	}
	else if (ZG_PROCESS_TYPE_IS_ARM64(processType))
	{
		return [ZGARM64DisassemblerObject isJumpMnemonic:mnemonic];
	}
	return NO;
}

+ (ZGMemorySize)instructionEncodingSizeForProcessType:(ZGProcessType)processType
{
	return (ZG_PROCESS_TYPE_IS_X86_64(processType) || ZG_PROCESS_TYPE_IS_I386(processType)) ? VARIABLE_INSTRUCTION_ENCODING_SIZE : 0x4;
}

@end
