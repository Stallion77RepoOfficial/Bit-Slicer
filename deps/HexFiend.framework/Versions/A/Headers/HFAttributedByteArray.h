//
//  HFAttributedByteArray.h
//  HexFiend_2
//
//  Copyright 2011 ridiculous_fish. All rights reserved.
//

#import <HexFiend/HFByteArray.h>


/*! @class HFAttributedByteArray
 @brief An extension of HFByteArray that supports attributes.
 
 HFAttributedByteArray is a subclass of HFByteArray that provides suitable overrides of the HFAttributes category.
*/


@class HFByteRangeAttributeArray;

@interface HFAttributedByteArray : HFByteArray {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-interface-ivars"
@private
    HFByteArray *impl;
    HFByteRangeAttributeArray *attributes;
#pragma clang diagnostic pop
}

@end
