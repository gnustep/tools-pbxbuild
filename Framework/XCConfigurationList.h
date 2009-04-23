@interface XCConfigurationList : PBObject
{
  NSMutableArray *_buildConfigurations;
  BOOL _defaultConfigurationIsVisible;
  NSString *_defaultConfigurationName;
}

// maintain build configurations...
- (NSArray *) buildConfigurations;
- (void) addBuildConfiguration: (XCBuildConfiguration *)bc;

- (BOOL) defaultConfigurationIsVisible;
- (void) setDefaultConfigurationIsVisible: (BOOL)flag;

- (NSString *) defaultConfigurationName;
- (void) setDefaultConfigurationName: (NSString *)name;
@end
