#import <Foundation/Foundation.h>
#import "PBObject.h"

@interface PBTarget : PBObject
{
  XCConfigurationList *buildConfigurationList;
  NSMutableArray *buildPhases;
  NSMutableArray *dependencies;
  NSString *name;
  NSString *productName;
  NSMutableArray *buildRules;
  PBXFileReference *productReference;
  NSString *productType;
}

@end
