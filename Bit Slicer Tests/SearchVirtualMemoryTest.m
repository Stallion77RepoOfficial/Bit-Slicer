/*
 * Copyright (c) 2014 Mayur Pawashe
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

#import <XCTest/XCTest.h>

#import "ZGVirtualMemory.h"
#import "ZGSearchFunctions.h"
#import "ZGSearchData.h"
#import "ZGSearchResults.h"
#import "ZGStoredData.h"
#import "ZGDataValueExtracting.h"

#include <TargetConditionals.h>

@interface SearchVirtualMemoryTest : XCTestCase

@end

@implementation SearchVirtualMemoryTest
{
	ZGMemoryMap _processTask;
	NSData *_data;
	ZGMemorySize _pageSize;
}

- (void)setUp
{
    [super setUp];
	
#if TARGET_CPU_ARM64
	XCTSkip("Virtual Memory Tests are not supported for arm64 yet");
#endif
	
	NSBundle *bundle = [NSBundle bundleForClass:[self class]];
	NSString *randomDataPath = [bundle pathForResource:@"random_data" ofType:@""];
	XCTAssertNotNil(randomDataPath);
	
	_data = [NSData dataWithContentsOfFile:randomDataPath];
	XCTAssertNotNil(_data);
	
	// We'll use our own process because it's a pain to use another one
	if (!ZGTaskForPID(getpid(), &_processTask))
	{
		XCTFail(@"Failed to grant access to task");
	}
	
	if (!ZGPageSize(_processTask, &_pageSize))
	{
		XCTFail(@"Failed to retrieve page size from task");
	}
	
	if (_pageSize * 5 != _data.length)
	{
		XCTFail(@"Page size %llu is not what we expected", _pageSize);
	}
}

- (ZGMemoryAddress)allocateDataIntoProcess
{
	ZGMemoryAddress address = 0x0;
	if (!ZGAllocateMemory(_processTask, &address, _data.length))
	{
		XCTFail(@"Failed to retrieve page size from task");
	}
	
	XCTAssertTrue(address % _pageSize == 0);
	
	if (!ZGProtect(_processTask, address, _data.length, VM_PROT_READ | VM_PROT_WRITE))
	{
		XCTFail(@"Failed to memory protect allocated data");
	}
	
	if (!ZGWriteBytes(_processTask, address, _data.bytes, _data.length))
	{
		XCTFail(@"Failed to write data into pages");
	}
	
	// Ensure the pages will be split in at least 3 different regions
	if (!ZGProtect(_processTask, address + _pageSize * 1, _pageSize, VM_PROT_ALL))
	{
		XCTFail(@"Failed to change page 2 protection to ALL");
	}
	if (!ZGProtect(_processTask, address + _pageSize * 3, _pageSize, VM_PROT_ALL))
	{
		XCTFail(@"Failed to change page 4 protection to ALL");
	}
	
	return address;
}

- (void)tearDown
{
    // Put teardown code here. This method is called after the invocation of each test method in the class.
	ZGDeallocatePort(_processTask);
	
    [super tearDown];
}

- (void)testFindingData
{
	ZGMemoryAddress address = [self allocateDataIntoProcess];
	
	uint8_t firstBytes[] = {0x00, 0xB1, 0x17, 0x11, 0x34, 0x03, 0x28, 0xD7, 0xD4, 0x98, 0x4A, 0xC2};
	void *bytes = malloc(sizeof(firstBytes));
	if (bytes == NULL)
	{
		XCTFail(@"Failed to allocate memory for first bytes...");
	}
	
	memcpy(bytes, firstBytes, sizeof(firstBytes));
	
	ZGSearchData *searchData = [[ZGSearchData alloc] initWithSearchValue:bytes dataSize:sizeof(firstBytes) dataAlignment:1 pointerSize:8];
	
	ZGSearchResults *results = ZGSearchForData(_processTask, searchData, nil, ZGByteArray, 0, ZGEquals);
	
	__block BOOL foundAddress = NO;
	[results enumerateWithCount:results.count removeResults:NO usingBlock:^(const void *resultAddressData, BOOL *stop) {
		ZGMemoryAddress resultAddress = *(const ZGMemoryAddress *)resultAddressData;
		if (resultAddress == address)
		{
			foundAddress = YES;
			*stop = YES;
		}
	}];
	
	XCTAssertTrue(foundAddress);
}

- (ZGSearchData *)searchDataFromBytes:(const void *)bytes size:(ZGMemorySize)size dataType:(ZGVariableType)dataType address:(ZGMemoryAddress)address alignment:(ZGMemorySize)alignment
{
	void *copiedBytes = malloc(size);
	if (copiedBytes == NULL)
	{
		XCTFail(@"Failed to allocate memory for copied bytes...");
	}
	
	memcpy(copiedBytes, bytes, size);
	
	ZGSearchData *searchData = [[ZGSearchData alloc] initWithSearchValue:copiedBytes dataSize:size dataAlignment:alignment pointerSize:8];
	searchData.beginAddress = address;
	searchData.endAddress = address + _data.length;
	searchData.swappedValue = ZGSwappedValue(ZGProcessTypeX86_64, bytes, dataType, size);
	
	return searchData;
}

- (void)testInt8Search
{
	ZGMemoryAddress address = [self allocateDataIntoProcess];
	uint8_t valueToFind = 0xB1;
	
	ZGSearchData *searchData = [self searchDataFromBytes:&valueToFind size:sizeof(valueToFind) dataType:ZGInt8 address:address alignment:1];
	searchData.savedData = [ZGStoredData storedDataFromProcessTask:_processTask beginAddress:searchData.beginAddress endAddress:searchData.endAddress protectionMode:searchData.protectionMode includeSharedMemory:NO];
	XCTAssertNotNil(searchData.savedData);
	
	ZGSearchResults *equalResults = ZGSearchForData(_processTask, searchData, nil, ZGInt8, ZGUnsigned, ZGEquals);
	XCTAssertEqual(equalResults.count, 89U);
	
	ZGSearchResults *equalSignedResults = ZGSearchForData(_processTask, searchData, nil, ZGInt8, ZGSigned, ZGEquals);
	XCTAssertEqual(equalSignedResults.count, 89U);
	
	ZGSearchResults *notEqualResults = ZGSearchForData(_processTask, searchData, nil, ZGInt8, ZGUnsigned, ZGNotEquals);
	XCTAssertEqual(notEqualResults.count, _data.length - 89U);
	
	ZGSearchResults *greaterThanResults = ZGSearchForData(_processTask, searchData, nil, ZGInt8, ZGUnsigned, ZGGreaterThan);
	XCTAssertEqual(greaterThanResults.count, 6228U);
	
	ZGSearchResults *lessThanResults = ZGSearchForData(_processTask, searchData, nil, ZGInt8, ZGUnsigned, ZGLessThan);
	XCTAssertEqual(lessThanResults.count, 14163U);
	
	searchData.shouldCompareStoredValues = YES;
	ZGSearchResults *storedEqualResults = ZGSearchForData(_processTask, searchData, nil, ZGInt8, ZGUnsigned, ZGEqualsStored);
	XCTAssertEqual(storedEqualResults.count, _data.length);
	searchData.shouldCompareStoredValues = NO;
	
	if (!ZGWriteBytes(_processTask, address + 0x1, (uint8_t []){valueToFind - 1}, 0x1))
	{
		XCTFail(@"Failed to write 2nd byte");
	}
	
	ZGSearchResults *emptyResults = [[ZGSearchResults alloc] initWithResultSets:@[] resultType:ZGSearchResultTypeDirect dataType:ZGInt8 stride:sizeof(ZGMemoryAddress) unalignedAccess:NO];
	
	ZGSearchResults *equalNarrowResults = ZGNarrowSearchForData(_processTask, NO, searchData, nil, ZGInt8, ZGUnsigned, ZGEquals, emptyResults, equalResults);
	XCTAssertEqual(equalNarrowResults.count, 88U);
	
	ZGSearchResults *notEqualNarrowResults = ZGNarrowSearchForData(_processTask, NO, searchData, nil, ZGInt8, ZGUnsigned, ZGNotEquals, emptyResults, equalResults);
	XCTAssertEqual(notEqualNarrowResults.count, 1U);
	
	ZGSearchResults *greaterThanNarrowResults = ZGNarrowSearchForData(_processTask, NO, searchData, nil, ZGInt8, ZGUnsigned, ZGGreaterThan, emptyResults, equalResults);
	XCTAssertEqual(greaterThanNarrowResults.count, 0U);
	
	ZGSearchResults *lessThanNarrowResults = ZGNarrowSearchForData(_processTask, NO, searchData, nil, ZGInt8, ZGUnsigned, ZGLessThan, emptyResults, equalResults);
	XCTAssertEqual(lessThanNarrowResults.count, 1U);
	
	searchData.shouldCompareStoredValues = YES;
	ZGSearchResults *storedEqualResultsNarrowed = ZGNarrowSearchForData(_processTask, NO, searchData, nil, ZGInt8, ZGUnsigned, ZGEqualsStored, emptyResults, storedEqualResults);
	XCTAssertEqual(storedEqualResultsNarrowed.count, _data.length - 1);
	searchData.shouldCompareStoredValues = NO;
	
	searchData.protectionMode = ZGProtectionExecute;
	
	ZGSearchResults *equalExecuteResults = ZGSearchForData(_processTask, searchData, nil, ZGInt8, ZGUnsigned, ZGEquals);
	XCTAssertEqual(equalExecuteResults.count, 34U);
	
	// this will ignore the 2nd byte we changed since it's out of range
	ZGSearchResults *equalExecuteNarrowResults = ZGNarrowSearchForData(_processTask, NO, searchData, nil, ZGInt8, ZGUnsigned, ZGEquals, emptyResults, equalResults);
	XCTAssertEqual(equalExecuteNarrowResults.count, 34U);
	
	ZGMemoryAddress *addressesRemoved = calloc(2, sizeof(*addressesRemoved));
	if (addressesRemoved == NULL) XCTFail(@"Failed to allocate memory for addressesRemoved");
	XCTAssertEqual(sizeof(ZGMemoryAddress), 8U);
	
	__block NSUInteger addressIndex = 0;
	[equalExecuteNarrowResults enumerateWithCount:2 removeResults:YES usingBlock:^(const void *resultAddressData, __unused BOOL *stop) {
		ZGMemoryAddress resultAddress = *(const ZGMemoryAddress *)resultAddressData;
		addressesRemoved[addressIndex] = resultAddress;
		addressIndex++;
	}];
	
	// first results do not have to be ordered
	addressesRemoved[0] ^= addressesRemoved[1];
	addressesRemoved[1] ^= addressesRemoved[0];
	addressesRemoved[0] ^= addressesRemoved[1];
	
	ZGSearchResults *equalExecuteNarrowTwiceResults = ZGNarrowSearchForData(_processTask, NO, searchData, nil, ZGInt8, ZGUnsigned, ZGEquals, emptyResults, equalExecuteNarrowResults);
	XCTAssertEqual(equalExecuteNarrowTwiceResults.count, 32U);
	
	ZGSearchResults *searchResultsRemoved = [[ZGSearchResults alloc] initWithResultSets:@[[NSData dataWithBytes:addressesRemoved length:2 * sizeof(*addressesRemoved)]] resultType:ZGSearchResultTypeDirect dataType:ZGInt8 stride:8 unalignedAccess:NO];
	
	ZGSearchResults *equalExecuteNarrowTwiceAgainResults = ZGNarrowSearchForData(_processTask, NO, searchData, nil, ZGInt8, ZGUnsigned, ZGEquals, searchResultsRemoved, equalExecuteNarrowResults);
	XCTAssertEqual(equalExecuteNarrowTwiceAgainResults.count, 34U);
	
	free(addressesRemoved);
	
	searchData.shouldCompareStoredValues = YES;
	ZGSearchResults *storedEqualExecuteNarrowResults = ZGNarrowSearchForData(_processTask, NO, searchData, nil, ZGInt8, ZGUnsigned, ZGEqualsStored, emptyResults, storedEqualResults);
	XCTAssertEqual(storedEqualExecuteNarrowResults.count, _pageSize * 2);
	searchData.shouldCompareStoredValues = NO;
	
	if (!ZGWriteBytes(_processTask, address + 0x1, (uint8_t []){valueToFind}, 0x1))
	{
		XCTFail(@"Failed to revert 2nd byte");
	}
}

- (void)testInt16Search
{
	ZGMemoryAddress address = [self allocateDataIntoProcess];
	int16_t valueToFind = -13398; // AA CB
	
	ZGSearchData *searchData = [self searchDataFromBytes:&valueToFind size:sizeof(valueToFind) dataType:ZGInt16 address:address alignment:sizeof(valueToFind)];
	
	ZGSearchResults *equalResults = ZGSearchForData(_processTask, searchData, nil, ZGInt16, ZGSigned, ZGEquals);
	XCTAssertEqual(equalResults.count, 1U);
	
	searchData.beginAddress += 0x291;
	ZGSearchResults *misalignedEqualResults = ZGSearchForData(_processTask, searchData, nil, ZGInt16, ZGSigned, ZGEquals);
	XCTAssertEqual(misalignedEqualResults.count, 1U);
	searchData.beginAddress -= 0x291;
	
	ZGSearchData *noAlignmentSearchData = [self searchDataFromBytes:&valueToFind size:sizeof(valueToFind) dataType:ZGInt16 address:address alignment:1];
	ZGSearchResults *noAlignmentEqualResults = ZGSearchForData(_processTask, noAlignmentSearchData, nil, ZGInt16, ZGSigned, ZGEquals);
	XCTAssertEqual(noAlignmentEqualResults.count, 2U);
	
	ZGMemoryAddress oldEndAddress = searchData.endAddress;
	searchData.beginAddress += 0x291;
	searchData.endAddress = searchData.beginAddress + 0x3;
	
	ZGSearchResults *noAlignmentRestrictedEqualResults = ZGNarrowSearchForData(_processTask, NO, searchData, nil, ZGInt16, ZGSigned, ZGEquals, [[ZGSearchResults alloc] initWithResultSets:@[] resultType:ZGSearchResultTypeDirect dataType:ZGInt16 stride:sizeof(ZGMemoryAddress) unalignedAccess:YES], noAlignmentEqualResults);
	XCTAssertEqual(noAlignmentRestrictedEqualResults.count, 1U);
	
	searchData.beginAddress -= 0x291;
	searchData.endAddress = oldEndAddress;
	
	int16_t swappedValue = (int16_t)CFSwapInt16((uint16_t)valueToFind);
	ZGSearchData *swappedSearchData = [self searchDataFromBytes:&swappedValue size:sizeof(swappedValue) dataType:ZGInt16 address:address alignment:sizeof(swappedValue)];
	swappedSearchData.bytesSwapped = YES;
	
	ZGSearchResults *equalSwappedResults = ZGSearchForData(_processTask, swappedSearchData, nil, ZGInt16, ZGUnsigned, ZGEquals);
	XCTAssertEqual(equalSwappedResults.count, 1U);
}

- (void)testInt32Search
{
	ZGMemoryAddress address = [self allocateDataIntoProcess];
	int32_t value = -300000000;
	ZGSearchData *searchData = [self searchDataFromBytes:&value size:sizeof(value) dataType:ZGInt32 address:address alignment:sizeof(value)];
	
	int32_t *topBound = malloc(sizeof(*topBound));
	*topBound = 300000000;
	searchData.rangeValue = topBound;
	
	ZGSearchResults *betweenResults = ZGSearchForData(_processTask, searchData, nil, ZGInt32, ZGSigned, ZGGreaterThan);
	XCTAssertEqual(betweenResults.count, 746U);
	
	int32_t *belowBound = malloc(sizeof(*belowBound));
	*belowBound = -600000000;
	searchData.rangeValue = belowBound;
	
	searchData.bytesSwapped = YES;
	
	ZGSearchResults *betweenSwappedResults = ZGSearchForData(_processTask, searchData, nil, ZGInt32, ZGSigned, ZGLessThan);
	XCTAssertEqual(betweenSwappedResults.count, 354U);
	
	searchData.savedData = [ZGStoredData storedDataFromProcessTask:_processTask beginAddress:searchData.beginAddress endAddress:searchData.endAddress protectionMode:searchData.protectionMode includeSharedMemory:NO];
	XCTAssertNotNil(searchData.savedData);
	
	int32_t *integerReadReference = NULL;
	ZGMemorySize integerSize = sizeof(*integerReadReference);
	if (!ZGReadBytes(_processTask, address + 0x54, (void **)&integerReadReference, &integerSize))
	{
		XCTFail(@"Failed to read integer at offset 0x54");
	}
	
	int32_t integerRead = (int32_t)CFSwapInt32BigToHost(*(uint32_t *)integerReadReference);
	
	ZGFreeBytes(integerReadReference, integerSize);
	
	int32_t *additiveConstant = malloc(sizeof(*additiveConstant));
	if (additiveConstant == NULL) XCTFail(@"Failed to malloc addititive constant");
	*additiveConstant = 10;
	
	int32_t *multiplicativeConstant = malloc(sizeof(*multiplicativeConstant));
	if (multiplicativeConstant == NULL) XCTFail(@"Failed to malloc multiplicative constant");
	*multiplicativeConstant = 3;
	
	searchData.additiveConstant = additiveConstant;
	searchData.multiplicativeConstant = multiplicativeConstant;
	searchData.shouldCompareStoredValues = YES;
	
	int32_t alteredInteger = (int32_t)CFSwapInt32HostToBig((uint32_t)((integerRead * *multiplicativeConstant + *additiveConstant)));
	if (!ZGWriteBytesIgnoringProtection(_processTask, address + 0x54, &alteredInteger, sizeof(alteredInteger)))
	{
		XCTFail(@"Failed to write altered integer at offset 0x54");
	}
	
	ZGSearchResults *narrowedSwappedAndStoredResults = ZGNarrowSearchForData(_processTask, NO, searchData, nil, ZGInt32, ZGSigned, ZGEqualsStoredLinear, [[ZGSearchResults alloc] initWithResultSets:@[] resultType:ZGSearchResultTypeDirect dataType:ZGInt32 stride:sizeof(ZGMemoryAddress) unalignedAccess:NO], betweenSwappedResults);
	XCTAssertEqual(narrowedSwappedAndStoredResults.count, 1U);
}

- (void)testInt64Search
{
	ZGMemoryAddress address = [self allocateDataIntoProcess];
	uint64_t value = 0x0B765697AFAA3400;
	
	ZGSearchData *searchData = [self searchDataFromBytes:&value size:sizeof(value) dataType:ZGInt64 address:address alignment:sizeof(value)];
	ZGSearchResults *results = ZGSearchForData(_processTask, searchData, nil, ZGInt64, ZGUnsigned, ZGLessThan);
	XCTAssertEqual(results.count, 132U);
	
	searchData.dataAlignment = sizeof(uint32_t);
	
	ZGSearchResults *resultsWithHalfAlignment = ZGSearchForData(_processTask, searchData, nil, ZGInt64, ZGUnsigned, ZGLessThan);
	XCTAssertEqual(resultsWithHalfAlignment.count, 256U);
	
	searchData.dataAlignment = sizeof(uint64_t);
	
	searchData.bytesSwapped = YES;
	ZGSearchResults *bigEndianResults = ZGSearchForData(_processTask, searchData, nil, ZGInt64, ZGUnsigned, ZGLessThan);
	XCTAssertEqual(bigEndianResults.count, 101U);
}

- (void)testFloatSearch
{
	ZGMemoryAddress address = [self allocateDataIntoProcess];
	float value = -0.036687f;
	ZGSearchData *searchData = [self searchDataFromBytes:&value size:sizeof(value) dataType:ZGFloat address:address alignment:sizeof(value)];
	searchData.epsilon = 0.0000001;
	
	ZGSearchResults *results = ZGSearchForData(_processTask, searchData, nil, ZGFloat, 0, ZGEquals);
	XCTAssertEqual(results.count, 1U);
	
	searchData.epsilon = 0.01;
	ZGSearchResults *resultsWithBigEpsilon = ZGSearchForData(_processTask, searchData, nil, ZGFloat, 0, ZGEquals);
	XCTAssertEqual(resultsWithBigEpsilon.count, 5U);
	
	float *bigEndianValue = malloc(sizeof(*bigEndianValue));
	if (bigEndianValue == NULL) XCTFail(@"bigEndianValue malloc'd is NULL");
	*bigEndianValue = 7522.56f;
	
	searchData.searchValue = bigEndianValue;
	searchData.bytesSwapped = YES;
	
	ZGSearchResults *bigEndianResults = ZGSearchForData(_processTask, searchData, nil, ZGFloat, 0, ZGEquals);
	XCTAssertEqual(bigEndianResults.count, 1U);
	
	searchData.epsilon = 100.0;
	ZGSearchResults *bigEndianResultsWithBigEpsilon = ZGSearchForData(_processTask, searchData, nil, ZGFloat, 0, ZGEquals);
	XCTAssertEqual(bigEndianResultsWithBigEpsilon.count, 2U);
}

- (void)testDoubleSearch
{
	ZGMemoryAddress address = [self allocateDataIntoProcess];
	double value = 100.0;
	
	ZGSearchData *searchData = [self searchDataFromBytes:&value size:sizeof(value) dataType:ZGDouble address:address alignment:sizeof(value)];
	
	ZGSearchResults *results = ZGSearchForData(_processTask, searchData, nil, ZGDouble, 0, ZGGreaterThan);
	XCTAssertEqual(results.count, 616U);
	
	searchData.dataAlignment = sizeof(float);
	searchData.endAddress = searchData.beginAddress + _pageSize;
	
	ZGSearchResults *resultsWithHalfAlignment = ZGSearchForData(_processTask, searchData, nil, ZGDouble, 0, ZGGreaterThan);
	XCTAssertEqual(resultsWithHalfAlignment.count, 250U);
	
	searchData.dataAlignment = sizeof(double);
	
	double *newValue = malloc(sizeof(*newValue));
	if (newValue == NULL) XCTFail(@"Failed to malloc newValue");
	*newValue = 4.56194e56;
	
	searchData.searchValue = newValue;
	searchData.bytesSwapped = YES;
	searchData.epsilon = 1e57;
	
	ZGSearchResults *swappedResults = ZGSearchForData(_processTask, searchData, nil, ZGDouble, 0, ZGEquals);
	XCTAssertEqual(swappedResults.count, 302U);
}

- (void)test8BitStringSearch
{
	ZGMemoryAddress address = [self allocateDataIntoProcess];
	
	char *hello = "hello";
	if (!ZGWriteBytes(_processTask, address + 96, hello, strlen(hello))) XCTFail(@"Failed to write hello string 1");
	if (!ZGWriteBytes(_processTask, address + 150, hello, strlen(hello))) XCTFail(@"Failed to write hello string 2");
	if (!ZGWriteBytes(_processTask, address + 5000, hello, strlen(hello) + 1)) XCTFail(@"Failed to write hello string 3");
	
	ZGSearchData *searchData = [self searchDataFromBytes:hello size:strlen(hello) + 1 dataType:ZGString8 address:address alignment:1];
	searchData.dataSize -= 1; // ignore null terminator for now
	
	ZGSearchResults *results = ZGSearchForData(_processTask, searchData, nil, ZGString8, 0, ZGEquals);
	XCTAssertEqual(results.count, 3U);
	
	if (!ZGWriteBytes(_processTask, address + 96, "m", 1)) XCTFail(@"Failed to write m");
	
	ZGSearchResults *narrowedResults = ZGNarrowSearchForData(_processTask, NO, searchData, nil, ZGString8, 0, ZGEquals, [[ZGSearchResults alloc] initWithResultSets:@[] resultType:ZGSearchResultTypeDirect dataType:ZGString8 stride:sizeof(ZGMemoryAddress) unalignedAccess:NO], results);
	XCTAssertEqual(narrowedResults.count, 2U);
	
	// .shouldIncludeNullTerminator field isn't "really" used for search functions; it's just a hint for UI state
	searchData.dataSize++;
	
	ZGSearchResults *narrowedTerminatedResults = ZGNarrowSearchForData(_processTask, NO, searchData, nil, ZGString8, 0, ZGEquals, [[ZGSearchResults alloc] initWithResultSets:@[] resultType:ZGSearchResultTypeDirect dataType:ZGString8 stride:sizeof(ZGMemoryAddress) unalignedAccess:NO], narrowedResults);
	XCTAssertEqual(narrowedTerminatedResults.count, 1U);
	
	searchData.dataSize--;
	if (!ZGWriteBytes(_processTask, address + 150, "HeLLo", strlen(hello))) XCTFail(@"Failed to write mixed case string");
	searchData.shouldIgnoreStringCase = YES;
	
	ZGSearchResults *narrowedIgnoreCaseResults = ZGNarrowSearchForData(_processTask, NO, searchData, nil, ZGString8, 0, ZGEquals, [[ZGSearchResults alloc] initWithResultSets:@[] resultType:ZGSearchResultTypeDirect dataType:ZGString8 stride:sizeof(ZGMemoryAddress) unalignedAccess:NO], narrowedResults);
	XCTAssertEqual(narrowedIgnoreCaseResults.count, 2U);
	
	if (!ZGWriteBytes(_processTask, address + 150, "M", 1)) XCTFail(@"Failed to write capital M");
	
	ZGSearchResults *narrowedIgnoreCaseNotEqualsResults = ZGNarrowSearchForData(_processTask, NO, searchData, nil, ZGString8, 0, ZGNotEquals, [[ZGSearchResults alloc] initWithResultSets:@[] resultType:ZGSearchResultTypeDirect dataType:ZGString8 stride:sizeof(ZGMemoryAddress) unalignedAccess:NO], narrowedIgnoreCaseResults);
	XCTAssertEqual(narrowedIgnoreCaseNotEqualsResults.count, 1U);
	
	searchData.shouldIgnoreStringCase = NO;
	
	ZGSearchResults *equalResultsAgain = ZGSearchForData(_processTask, searchData, nil, ZGString8, 0, ZGEquals);
	XCTAssertEqual(equalResultsAgain.count, 1U);
	
	searchData.beginAddress = address + _pageSize;
	searchData.endAddress = address + _pageSize * 2;
	
	ZGSearchResults *notEqualResults = ZGSearchForData(_processTask, searchData, nil, ZGString8, 0, ZGNotEquals);
	XCTAssertEqual(notEqualResults.count, _pageSize - 1 - (strlen(hello) - 1)); // take account for bytes at end that won't be compared
}

- (void)test16BitStringSearch
{
	ZGMemoryAddress address = [self allocateDataIntoProcess];
	
	NSString *helloString = @"hello";
	unichar *helloBytes = calloc(helloString.length + 1, sizeof(*helloBytes));
	if (helloBytes == NULL) XCTFail(@"Failed to write calloc hello bytes");
	
	[helloString getBytes:helloBytes maxLength:sizeof(*helloBytes) * helloString.length usedLength:NULL encoding:NSUTF16LittleEndianStringEncoding options:NSStringEncodingConversionAllowLossy range:NSMakeRange(0, helloString.length) remainingRange:NULL];
	
	size_t helloLength = helloString.length * sizeof(unichar);
	
	if (!ZGWriteBytes(_processTask, address + 96, helloBytes, helloLength)) XCTFail(@"Failed to write hello string 1");
	if (!ZGWriteBytes(_processTask, address + 150, helloBytes, helloLength)) XCTFail(@"Failed to write hello string 2");
	if (!ZGWriteBytes(_processTask, address + 5000, helloBytes, helloLength)) XCTFail(@"Failed to write hello string 3");
	if (!ZGWriteBytes(_processTask, address + 6001, helloBytes, helloLength)) XCTFail(@"Failed to write hello string 4");
	
	ZGSearchData *searchData = [self searchDataFromBytes:helloBytes size:helloLength + sizeof(unichar) dataType:ZGString16 address:address alignment:sizeof(unichar)];
	searchData.dataSize -= sizeof(unichar);
	
	ZGSearchResults *equalResults = ZGSearchForData(_processTask, searchData, nil, ZGString16, 0, ZGEquals);
	XCTAssertEqual(equalResults.count, 4U);
	
	ZGSearchResults *notEqualResults = ZGSearchForData(_processTask, searchData, nil, ZGString16, 0, ZGNotEquals);
	XCTAssertEqual(notEqualResults.count, _data.length / sizeof(unichar) - 3 - 4*5);
	
	searchData.dataAlignment = 1;
	
	ZGSearchResults *equalResultsWithNoAlignment = ZGSearchForData(_processTask, searchData, nil, ZGString16, 0, ZGEquals);
	XCTAssertEqual(equalResultsWithNoAlignment.count, 4U);
	
	searchData.dataAlignment = 2;
	
	NSString *mooString = @"moo";
	unichar *mooBytes = calloc(mooString.length + 1, sizeof(*mooBytes));
	if (mooBytes == NULL) XCTFail(@"Failed to write calloc moo bytes");
	
	[mooString getBytes:mooBytes maxLength:sizeof(*mooBytes) * mooString.length usedLength:NULL encoding:NSUTF16LittleEndianStringEncoding options:NSStringEncodingConversionAllowLossy range:NSMakeRange(0, mooString.length) remainingRange:NULL];
	
	size_t mooLength = mooString.length * sizeof(unichar);
	if (!ZGWriteBytes(_processTask, address + 5000, mooBytes, mooLength)) XCTFail(@"Failed to write moo string");
	
	ZGSearchData *mooSearchData = [self searchDataFromBytes:mooBytes size:mooLength dataType:ZGString16 address:address alignment:sizeof(unichar)];
	
	ZGSearchResults *equalNarrowedResults = ZGNarrowSearchForData(_processTask, NO, mooSearchData, nil, ZGString16, 0, ZGEquals, [[ZGSearchResults alloc] initWithResultSets:@[] resultType:ZGSearchResultTypeDirect dataType:ZGString16 stride:sizeof(ZGMemoryAddress) unalignedAccess:NO], equalResults);
	XCTAssertEqual(equalNarrowedResults.count, 1U);
	
	mooSearchData.shouldIgnoreStringCase = YES;
	const char *mooMixedCase = [@"MoO" cStringUsingEncoding:NSUTF16LittleEndianStringEncoding];
	if (!ZGWriteBytes(_processTask, address + 5000, mooMixedCase, mooLength)) XCTFail(@"Failed to write moo mixed string");
	
	ZGSearchResults *equalNarrowedIgnoreCaseResults = ZGNarrowSearchForData(_processTask, NO, mooSearchData, nil, ZGString16, 0, ZGEquals, [[ZGSearchResults alloc] initWithResultSets:@[] resultType:ZGSearchResultTypeDirect dataType:ZGString16 stride:sizeof(ZGMemoryAddress) unalignedAccess:NO], equalResults);
	XCTAssertEqual(equalNarrowedIgnoreCaseResults.count, 1U);
	
	NSString *nooString = @"noo";
	unichar *nooBytes = calloc(nooString.length + 1, sizeof(unichar));
	if (nooBytes == NULL) XCTFail(@"Failed to write calloc noo bytes");
	
	[nooString getBytes:nooBytes maxLength:sizeof(*nooBytes) * nooString.length usedLength:NULL encoding:NSUTF16LittleEndianStringEncoding options:NSStringEncodingConversionAllowLossy range:NSMakeRange(0, nooString.length) remainingRange:NULL];
	
	size_t nooLength = nooString.length * sizeof(unichar);
	if (!ZGWriteBytes(_processTask, address + 5000, nooBytes, nooLength)) XCTFail(@"Failed to write noo string");
	
	ZGSearchResults *equalNarrowedIgnoreCaseFalseResults = ZGNarrowSearchForData(_processTask, NO, mooSearchData, nil, ZGString16, 0, ZGEquals, [[ZGSearchResults alloc] initWithResultSets:@[] resultType:ZGSearchResultTypeDirect dataType:ZGString16 stride:sizeof(ZGMemoryAddress) unalignedAccess:NO], equalResults);
	XCTAssertEqual(equalNarrowedIgnoreCaseFalseResults.count, 0U);
	
	ZGSearchResults *notEqualNarrowedIgnoreCaseResults = ZGNarrowSearchForData(_processTask, NO, searchData, nil, ZGString16, 0, ZGNotEquals, [[ZGSearchResults alloc] initWithResultSets:@[] resultType:ZGSearchResultTypeDirect dataType:ZGString16 stride:sizeof(ZGMemoryAddress) unalignedAccess:NO], equalResults);
	XCTAssertEqual(notEqualNarrowedIgnoreCaseResults.count, 1U);
	
	ZGSearchData *nooSearchData = [self searchDataFromBytes:nooBytes size:nooLength dataType:ZGString16 address:address alignment:sizeof(unichar)];
	nooSearchData.beginAddress = address + _pageSize;
	nooSearchData.endAddress = address + _pageSize * 2;
	
	ZGSearchResults *nooEqualResults = ZGSearchForData(_processTask, nooSearchData, nil, ZGString16, 0, ZGEquals);
	XCTAssertEqual(nooEqualResults.count, 1U);
	
	ZGSearchResults *nooNotEqualResults = ZGSearchForData(_processTask, nooSearchData, nil, ZGString16, 0, ZGNotEquals);
	XCTAssertEqual(nooNotEqualResults.count, _pageSize / 2 - 1 - 2);
	
	unichar *helloBigBytes = calloc(helloString.length + 1, sizeof(unichar));
	if (helloBigBytes == NULL) XCTFail(@"Failed to write calloc helloBigBytes");
	
	[helloString getBytes:helloBigBytes maxLength:sizeof(*helloBigBytes) * helloString.length usedLength:NULL encoding:NSUTF16BigEndianStringEncoding options:NSStringEncodingConversionAllowLossy range:NSMakeRange(0, helloString.length) remainingRange:NULL];
	
	if (!ZGWriteBytes(_processTask, address + 7000, helloBigBytes, helloLength)) XCTFail(@"Failed to write hello big string");
	
	searchData.bytesSwapped = YES;
	
	ZGSearchResults *equalResultsBig = ZGSearchForData(_processTask, searchData, nil, ZGString16, 0, ZGEquals);
	XCTAssertEqual(equalResultsBig.count, 1U);
	
	ZGSearchResults *equalResultsBigNarrow = ZGNarrowSearchForData(_processTask, NO, searchData, nil, ZGString16, 0, ZGEquals, [[ZGSearchResults alloc] initWithResultSets:@[] resultType:ZGSearchResultTypeDirect dataType:ZGString16 stride:sizeof(ZGMemoryAddress) unalignedAccess:NO], equalResultsBig);
	XCTAssertEqual(equalResultsBigNarrow.count, 1U);
	
	unichar capitalHByte = 0x0;
	[@"H" getBytes:&capitalHByte maxLength:sizeof(capitalHByte) usedLength:NULL encoding:NSUTF16BigEndianStringEncoding options:NSStringEncodingConversionAllowLossy range:NSMakeRange(0, 1) remainingRange:NULL];
	
	if (!ZGWriteBytes(_processTask, address + 7000, &capitalHByte, sizeof(capitalHByte))) XCTFail(@"Failed to write capital H string");
	
	ZGSearchResults *equalResultsBigNarrowTwice = ZGNarrowSearchForData(_processTask, NO, searchData, nil, ZGString16, 0, ZGEquals, [[ZGSearchResults alloc] initWithResultSets:@[] resultType:ZGSearchResultTypeDirect dataType:ZGString16 stride:sizeof(ZGMemoryAddress) unalignedAccess:NO], equalResultsBigNarrow);
	XCTAssertEqual(equalResultsBigNarrowTwice.count, 0U);

	ZGSearchResults *notEqualResultsBigNarrowTwice = ZGNarrowSearchForData(_processTask, NO, searchData, nil, ZGString16, 0, ZGNotEquals, [[ZGSearchResults alloc] initWithResultSets:@[] resultType:ZGSearchResultTypeDirect dataType:ZGString16 stride:sizeof(ZGMemoryAddress) unalignedAccess:NO], equalResultsBigNarrow);
	XCTAssertEqual(notEqualResultsBigNarrowTwice.count, 1U);

	searchData.shouldIgnoreStringCase = YES;

	ZGSearchResults *equalResultsBigNarrowThrice = ZGNarrowSearchForData(_processTask, NO, searchData, nil, ZGString16, 0, ZGEquals, [[ZGSearchResults alloc] initWithResultSets:@[] resultType:ZGSearchResultTypeDirect dataType:ZGString16 stride:sizeof(ZGMemoryAddress) unalignedAccess:NO], equalResultsBigNarrow);
	XCTAssertEqual(equalResultsBigNarrowThrice.count, 1U);
	
	ZGSearchResults *equalResultsBigCaseInsenitive = ZGSearchForData(_processTask, searchData, nil, ZGString16, 0, ZGEquals);
	XCTAssertEqual(equalResultsBigCaseInsenitive.count, 1U);
	
	searchData.dataSize += sizeof(unichar);
	// .shouldIncludeNullTerminator is not necessary to set, only used for UI state
	
	ZGSearchResults *equalResultsBigCaseInsenitiveNullTerminatedNarrowed = ZGNarrowSearchForData(_processTask, NO, searchData, nil, ZGString16, 0, ZGEquals, [[ZGSearchResults alloc] initWithResultSets:@[] resultType:ZGSearchResultTypeDirect dataType:ZGString16 stride:sizeof(ZGMemoryAddress) unalignedAccess:NO], equalResultsBigCaseInsenitive);
	XCTAssertEqual(equalResultsBigCaseInsenitiveNullTerminatedNarrowed.count, 0U);

	unichar zero = 0x0;
	if (!ZGWriteBytes(_processTask, address + 7000 + helloLength, &zero, sizeof(zero))) XCTFail(@"Failed to write zero");
	
	ZGSearchResults *equalResultsBigCaseInsenitiveNullTerminatedNarrowedTwice = ZGNarrowSearchForData(_processTask, NO, searchData, nil, ZGString16, 0, ZGEquals, [[ZGSearchResults alloc] initWithResultSets:@[] resultType:ZGSearchResultTypeDirect dataType:ZGString16 stride:sizeof(ZGMemoryAddress) unalignedAccess:NO], equalResultsBigCaseInsenitive);
	XCTAssertEqual(equalResultsBigCaseInsenitiveNullTerminatedNarrowedTwice.count, 1U);

	ZGSearchResults *equalResultsBigCaseInsensitiveNullTerminated = ZGSearchForData(_processTask, searchData, nil, ZGString16, 0, ZGEquals);
	XCTAssertEqual(equalResultsBigCaseInsensitiveNullTerminated.count, 1U);

	const ZGMemorySize regionCount = 5;
	const ZGMemorySize chancesMissedPerRegion = 5;
	ZGSearchResults *notEqualResultsBigCaseInsensitiveNullTerminated = ZGSearchForData(_processTask, searchData, nil, ZGString16, 0, ZGNotEquals);
	XCTAssertEqual(notEqualResultsBigCaseInsensitiveNullTerminated.count, _data.length / sizeof(unichar) - regionCount * chancesMissedPerRegion - equalResultsBigCaseInsensitiveNullTerminated.count);

	searchData.shouldIgnoreStringCase = NO;
	searchData.bytesSwapped = NO;

	ZGSearchResults *equalResultsNullTerminated = ZGSearchForData(_processTask, searchData, nil, ZGString16, 0, ZGEquals);
	XCTAssertEqual(equalResultsNullTerminated.count, 0U);

	if (!ZGWriteBytes(_processTask, address + 96 + helloLength, &zero, sizeof(zero))) XCTFail(@"Failed to write zero 2nd time");

	ZGSearchResults *equalResultsNullTerminatedTwice = ZGSearchForData(_processTask, searchData, nil, ZGString16, 0, ZGEquals);
	XCTAssertEqual(equalResultsNullTerminatedTwice.count, 1U);

	ZGSearchResults *equalResultsNullTerminatedNarrowed = ZGNarrowSearchForData(_processTask, NO, searchData, nil, ZGString16, 0, ZGEquals, [[ZGSearchResults alloc] initWithResultSets:@[] resultType:ZGSearchResultTypeDirect dataType:ZGString16 stride:sizeof(ZGMemoryAddress) unalignedAccess:NO], equalResultsNullTerminatedTwice);
	XCTAssertEqual(equalResultsNullTerminatedNarrowed.count, 1U);

	if (!ZGWriteBytes(_processTask, address + 96 + helloLength, helloBytes, sizeof(zero))) XCTFail(@"Failed to write first character");

	ZGSearchResults *equalResultsNullTerminatedNarrowedTwice = ZGNarrowSearchForData(_processTask, NO, searchData, nil, ZGString16, 0, ZGEquals, [[ZGSearchResults alloc] initWithResultSets:@[] resultType:ZGSearchResultTypeDirect dataType:ZGString16 stride:sizeof(ZGMemoryAddress) unalignedAccess:NO], equalResultsNullTerminatedNarrowed);
	XCTAssertEqual(equalResultsNullTerminatedNarrowedTwice.count, 0U);

	ZGSearchResults *notEqualResultsNullTerminatedNarrowedTwice = ZGNarrowSearchForData(_processTask, NO, searchData, nil, ZGString16, 0, ZGNotEquals, [[ZGSearchResults alloc] initWithResultSets:@[] resultType:ZGSearchResultTypeDirect dataType:ZGString16 stride:sizeof(ZGMemoryAddress) unalignedAccess:NO], equalResultsNullTerminatedNarrowed);
	XCTAssertEqual(notEqualResultsNullTerminatedNarrowedTwice.count, 1U);
}

- (void)testByteArraySearch
{
	ZGMemoryAddress address = [self allocateDataIntoProcess];
	uint8_t bytes[] = {0xC6, 0xED, 0x8F, 0x0D};
	
	ZGSearchData *searchData = [self searchDataFromBytes:bytes size:sizeof(bytes) dataType:ZGByteArray address:address alignment:1];
	
	ZGSearchResults *equalResults = ZGSearchForData(_processTask, searchData, nil, ZGByteArray, 0, ZGEquals);
	XCTAssertEqual(equalResults.count, 1U);
	
	ZGSearchResults *notEqualResults = ZGSearchForData(_processTask, searchData, nil, ZGByteArray, 0, ZGNotEquals);
	XCTAssertEqual(notEqualResults.count, _data.length - 1 - 3*5);
	
	uint8_t changedBytes[] = {0xC8, 0xED, 0xBF, 0x0D};
	if (!ZGWriteBytes(_processTask, address + 0x21D4, changedBytes, sizeof(changedBytes))) XCTFail(@"Failed to write changed bytes");
	
	NSString *wildcardExpression = @"C? ED *F 0D";
	unsigned char *byteArrayFlags = ZGAllocateFlagsForByteArrayWildcards(wildcardExpression);
	if (byteArrayFlags == NULL) XCTFail(@"Byte array flags is NULL");
	
	searchData.byteArrayFlags = byteArrayFlags;
	searchData.searchValue = ZGValueFromString(ZGProcessTypeX86_64, wildcardExpression, ZGByteArray, NULL);
	
	ZGSearchResults *equalResultsWildcards = ZGSearchForData(_processTask, searchData, nil, ZGByteArray, 0, ZGEquals);
	XCTAssertEqual(equalResultsWildcards.count, 1U);
	
	uint8_t changedBytesAgain[] = {0xD9, 0xED, 0xBF, 0x0D};
	if (!ZGWriteBytes(_processTask, address + 0x21D4, changedBytesAgain, sizeof(changedBytesAgain))) XCTFail(@"Failed to write changed bytes again");
	
	ZGSearchResults *equalResultsWildcardsNarrowed = ZGNarrowSearchForData(_processTask, NO, searchData, nil, ZGByteArray, 0, ZGEquals, [[ZGSearchResults alloc] initWithResultSets:@[] resultType:ZGSearchResultTypeDirect dataType:ZGByteArray stride:sizeof(ZGMemoryAddress) unalignedAccess:NO], equalResultsWildcards);
	XCTAssertEqual(equalResultsWildcardsNarrowed.count, 0U);
	
	ZGSearchResults *notEqualResultsWildcardsNarrowed = ZGNarrowSearchForData(_processTask, NO, searchData, nil, ZGByteArray, 0, ZGNotEquals, [[ZGSearchResults alloc] initWithResultSets:@[] resultType:ZGSearchResultTypeDirect dataType:ZGByteArray stride:sizeof(ZGMemoryAddress) unalignedAccess:NO], equalResultsWildcards);
	XCTAssertEqual(notEqualResultsWildcardsNarrowed.count, 1U);
}

@end
