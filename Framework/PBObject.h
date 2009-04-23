#import <Foundation/Foundation.h>

@interface PBObject : NSObject
{
  Class *pbIsa;
}

// Accessors...
- (Class) pbIsa;
- (void) setPbIsa: (Class)cls;
@end
