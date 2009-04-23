#import <Foundation/Foundation.h>

@interface PBUnarchiver : NSObject
{
  NSMutableArray *objects;
  NSString *archiveVersion;
  NSString *objectVersion;
  NSMutableArray *classes;
}

//
// Initialializers...
//
- (id) initWithContentsOfFile: (NSString *)fileName;
+ (id) unarchiveWithContentsOfFile: (NSString *)fileName;

//
// Accessors...
//
- (NSMutableArray *) objects;
- (void) setObjects: (NSMutableArray *)objs;

- (NSString *) archiveVersion;
- (void) setArchiveVersion: (NSString *)version;

- (NSString *) objectVersion;
- (void) setObjectVersion: (NSString *)version;

- (NSMutableArray *) classes;
- (void) setClasses: (NSMutableArray *)ca;

//
// Operational methods...
//
- (void) resolveReferences;
@end
