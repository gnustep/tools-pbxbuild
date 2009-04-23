@interface XCBuildConfiguration : PBObject
{
  PBXFileReference *_baseConfigurationReference;
  NSDictionary *_buildSettings;
  NSString *_name;
}

- (PBXFileReference *) baseConfigurationReference;
- (void) setBaseConfigurationReference: (PBXFileReference *) fileRef;

- (NSDictionary *) buildSettings;
- (void) setBuildSettings: (NSDictionary *)dict;

- (NSString *) name;
- (void) setName: (NSString *)name;
@end
