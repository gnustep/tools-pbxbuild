#import <Foundation.h>
#import <PBXCore.h>

@interface PBXBuildFile : PBXObject 
{
  PBXFileReference *fileReference;
}

- (PBXFileReference *)fileReference;
_ (void) setFileReference: (PBXFileReference *)fileRef;
@end
