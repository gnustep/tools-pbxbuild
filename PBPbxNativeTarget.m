/*
   Project: pbxbuild

   Copyright (C) 2006 Free Software Foundation

   Author: Hans Baier,,,

   Created: 2006-08-11 11:49:37 +0200 by jack

   This application is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public
   License as published by the Free Software Foundation; either
   version 2 of the License, or (at your option) any later version.

   This application is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   Library General Public License for more details.

   You should have received a copy of the GNU General Public
   License along with this library; if not, write to the Free
   Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111 USA.
*/

#include "PBPbxNativeTarget.h"
#include "PBPbxProject.h"
#include "PBDevelopmentHelper.h"

@interface PBPbxNativeTarget (Private)
/**
 * rawType is transformed into a GNUmakefile compliant string
 * e.g. com.apple.product-type.application -> app
 */

- (NSString *) standardizeTigerTargetType: (NSString *)rawType;

/**
 * the targets isa field is transformed to a standard target type
 * e.g. PBXApplicationTarget -> app
 */

- (NSString *) standardizePantherTargetType: (NSString *)targetIsa;

/**
 * This sets up the paths where the compiler should search 
 * for include directories
 */
- (void) setUpIncludeDirsForTarget: (NSDictionary *)target;

/**
 * This adds all path components in the given array to include paths
 * e.g. foo, bar, baz -> foo, foo/bar, foo/bar/baz
 */
- (void) addPathComponentsToIncludeDirs: (NSArray *)pathComponents;

/**
 * get the build settings for tiger projects
 */
- (NSDictionary *) getBuildSettingsTigerForTarget: (NSDictionary *)target;

/**
 * Cycles through all the Build Phases and extracts the file names
 * for Headers, Sources, returns whether the target could be
 * processed successfully
 */
- (BOOL) traverseBuildPhasesOfTarget: (NSDictionary *)target;

/**
 * Gets the type for the file.
 */
- (NSString *) lookupResourceTypeOfPbxBuildFileRef: (NSString *)fileRef;

/**
 * retrieves all the files belonging to source buildPhase and stores the
 * into the dictionary.
 */
- (void) retrieveSourceFileListFromBuildPhase: (NSDictionary *)buildPhase
			     andStoreResultIn: (NSMutableDictionary *)aDictionary;

/**
 * retrieves all the files belonging to buildPhase and stores the
 * List of files in anArray
 */
- (void) retrieveFileListFromBuildPhase: (NSDictionary *)buildPhase
		       andStoreResultIn: (NSMutableArray *)anArray;
/**
 * looks up the path from the file handle in the PBX*BuildPhase
 * and stores the file references
 */
- (NSString *) lookupResourcesOfPbxBuildFileRef: (NSString *)fHandle;

/**
 * checks whether the file is in a group with group path
 * and if so, appends the group path and adds the result to anArray
 */
- (void)              addPath: (NSString *)path 
         withFileReferenceKey: (NSString *)fHandle 
                      toArray: (NSMutableArray *)anArray
			 type: (NSString *)type;
@end

@implementation PBPbxNativeTarget (Private)
- (NSString *) standardizeTigerTargetType: (NSString *)rawType
{
  if ([@"com.apple.product-type.application" isEqual: rawType])
    return @"app";
  if ([@"com.apple.product-type.framework" isEqual: rawType])
    return @"framework";
  if ([@"com.apple.product-type.tool" isEqual: rawType])
    return @"tool";
  if ([@"com.apple.product-type.bundle" isEqual: rawType])
    return @"bundle";

  return nil;
}

- (NSString *) standardizePantherTargetType: (NSString *)targetIsa
{
  if([@"PBXApplicationTarget" isEqual: targetIsa])
    return @"app";
  if([@"PBXBundleTarget" isEqual: targetIsa])
    return @"bundle";
  if([@"PBXFrameworkTarget" isEqual: targetIsa])
    return @"framework";

  return nil;
}

- (BOOL) traverseBuildPhasesOfTarget: (NSDictionary *)target
{
  NSDictionary *buildSettings;
  NSString     *buildPhaseKey;
  NSDictionary *buildPhase;
  NSEnumerator *e;

  if([[project version] isEqual: PBX_VERSION_TIGER]) 
    {
      if(![[target objectForKey: @"isa"] isEqual: @"PBXNativeTarget"])
        {
          NSLog(@"Don't know how to handle target with type: %@, skipping...",
                [target objectForKey: @"isa"] );
          return NO; 
        }      
      buildSettings = [self getBuildSettingsTigerForTarget: target];    
      ASSIGN(targetType, [self standardizeTigerTargetType: 
                                 [target objectForKey: @"productType"]]);
    }
  else if([[project version] isEqual: PBX_VERSION_PANTHER])
    {
      buildSettings = [target objectForKey: @"buildSettings"];
      ASSIGN(targetType, [self standardizePantherTargetType: 
				 [target objectForKey: @"isa"]]);
    }
  else
    {
      NSLog(@"Unsupported project version: '%@', quitting...",[project version]);
      exit(EXIT_FAILURE);
    }

  ASSIGN(targetName, [buildSettings objectForKey: @"PRODUCT_NAME"]);
  if(targetName == nil)
    {
      ASSIGN(targetName, [target objectForKey: @"name"]);
    }

  if(targetType == nil)
    {
      NSLog(@"Don't know how to handle target type: '%@', quitting...", 
	    [target objectForKey: @"productType"]);
      exit(EXIT_FAILURE);
    }

  if([[project version] isEqual: PBX_VERSION_PANTHER]) 
    {
      infoPlistFile = nil;
      ASSIGN(infoPlist, [[target objectForKey: @"productSettingsXML"] 
			  propertyList]);
      
    }
  else if([[project version] isEqual: PBX_VERSION_TIGER])
    {
      ASSIGN(infoPlistFile, [buildSettings objectForKey: @"INFOPLIST_FILE"]);
      ASSIGN(infoPlist, [NSDictionary 
			  dictionaryWithContentsOfFile: infoPlistFile]);
    }
  
  ASSIGN(productVersion, [infoPlist objectForKey: @"CFBundleVersion"]);

  // this one will be symlinked to the real Info.plist file
  [resources addObject: @"Info-gnustep.plist"];

  // get the files involved in building the target
  e = [[target objectForKey: @"buildPhases"] objectEnumerator];
  while ( (buildPhaseKey = [e nextObject]) )
    {
      NSString *buildPhaseType;

      // buildPhase is just a reference, so look it up
      buildPhase = [objects objectForKey: buildPhaseKey];
      buildPhaseType = [buildPhase objectForKey: @"isa"];
      if ([buildPhaseType isEqual: @"PBXHeadersBuildPhase"])
	{
	  [self retrieveFileListFromBuildPhase: buildPhase 
		andStoreResultIn: headers];
	}
      else if ([buildPhaseType isEqual: @"PBXSourcesBuildPhase"])
	{
	  [self retrieveSourceFileListFromBuildPhase: buildPhase 
		andStoreResultIn: sources];
	}
       else if ([buildPhaseType isEqual: @"PBXResourcesBuildPhase"])
 	{
	  [self retrieveFileListFromBuildPhase: buildPhase 
		andStoreResultIn: resources];
	}
      else if ([buildPhaseType isEqual: @"PBXFrameworksBuildPhase"])
	{
	  [self retrieveFileListFromBuildPhase: buildPhase 
		andStoreResultIn: frameworks];
	}
      else
	NSLog(@"Skipping Build Phase %@, not recognized yet", buildPhaseType);
    }
  return YES;
}

- (void) setUpIncludeDirsForTarget: (NSDictionary *)target
{
  NSArray      *buildConfigurationKeys = 
    [[objects objectForKey: [target objectForKey: @"buildConfigurationList"]]
      objectForKey: @"buildConfigurations"];
  NSEnumerator *e = [buildConfigurationKeys objectEnumerator];
  NSString     *headerSearchPaths;
  NSString     *buildConfigurationKey;

  if([[project version] isEqual: PBX_VERSION_PANTHER])
    {
      headerSearchPaths = [[target objectForKey: @"buildSettings"]
			    objectForKey: @"HEADER_SEARCH_PATHS"];
      [self addPathComponentsToIncludeDirs: 
	      [headerSearchPaths pathComponents]];
    }
  else
    while ( (buildConfigurationKey = [e nextObject]) )
      {
	NSDictionary *buildConfiguration = 
	  [objects objectForKey: buildConfigurationKey];
	
	if (![[buildConfiguration objectForKey: @"name"] 
	       isEqual: @"Development"])
	  continue;
	
	headerSearchPaths = 
	  [[buildConfiguration objectForKey: @"buildSettings"]
			      objectForKey: @"HEADER_SEARCH_PATHS"];

	[self addPathComponentsToIncludeDirs: 
		[headerSearchPaths pathComponents]];
      }
}

- (void) addPathComponentsToIncludeDirs: (NSArray *)pathComponents
{
  int i;

  // add all Directories in the path to the array
  for (i=0; i<[pathComponents count]; i++)
    {
      NSRange range;
      range.location = 0;
      range.length   = i+1;
	  
      [includeDirs addObject: 
		     [NSString pathWithComponents:
				 [pathComponents subarrayWithRange: range]
		      ]
       ];
    }
}

- (NSDictionary *) getBuildSettingsTigerForTarget: (NSDictionary *)target
{
  NSDictionary *buildConfigurationList;
  NSDictionary *defaultConfiguration;
  NSString     *defaultConfigurationType;

  // get target name and type
  buildConfigurationList = 
    [objects objectForKey: [target objectForKey: 
				     @"buildConfigurationList"]];
  // the last object in the buildConfigurationList is the
  // defaultConfiguration
  defaultConfiguration = 
    [objects objectForKey: 
	       [[buildConfigurationList objectForKey: 
					 @"buildConfigurations"]
		 lastObject]];
  defaultConfigurationType = [defaultConfiguration objectForKey: @"isa"];
  if (![@"XCBuildConfiguration" isEqual: defaultConfigurationType])
    {
      NSLog(@"FATAL: expected 'XCBuildConfiguration', but got '%@'",
	defaultConfigurationType);
      exit (EXIT_FAILURE);
    }
  
  return [defaultConfiguration objectForKey: @"buildSettings"];
}


- (NSString *) lookupResourceTypeOfPbxBuildFileRef: (NSString *)pbxFileRef
{
  NSDictionary *pbxBuildFile     = [objects objectForKey: pbxFileRef];
  NSString     *fileRef          = [pbxBuildFile objectForKey: @"fileRef"];
  NSDictionary *pbxFileReference = [objects objectForKey: fileRef];
  NSString *type = [pbxFileReference objectForKey: @"lastKnownFileType"];
  
  if(type == nil)
    {
      type = [pbxFileReference objectForKey: @"explicitFileType"];
    }
  
  return type;
}

- (void) retrieveSourceFileListFromBuildPhase: (NSDictionary *)buildPhase
			     andStoreResultIn: (NSMutableDictionary *)aDictionary
{
  NSArray      *files          = [buildPhase objectForKey: @"files"];
  NSString     *buildPhaseType = [buildPhase objectForKey: @"isa"];
  NSEnumerator *e              = [files objectEnumerator];
  NSString     *pbxBuildFile;
  NSMutableArray *cFiles, *mFiles, *cppFiles;

  // File arrays...
  cFiles = [NSMutableArray arrayWithCapacity: 50];
  mFiles = [NSMutableArray arrayWithCapacity: 50];
  cppFiles = [NSMutableArray arrayWithCapacity: 50];
 
  // Add files...
  NSDebugMLog(@"Adding files for buildPhase: %@", buildPhaseType);
  while ( (pbxBuildFile = [e nextObject]) )
    {
      NSString *pbxFileReference = [[objects objectForKey: pbxBuildFile] 
				     objectForKey: @"fileRef"];
      NSString *path = [self lookupResourcesOfPbxBuildFileRef: pbxBuildFile];
      NSString *type = [self lookupResourceTypeOfPbxBuildFileRef: pbxBuildFile];
      
      NSDebugMLog(@"Looking up file handle: %@", pbxBuildFile);
      if([type isEqual: @"sourcecode.c.c"])
	{
	  [self addPath: path 
		withFileReferenceKey: pbxFileReference
		toArray: cFiles
		type: buildPhaseType];
	}
      else if([type isEqual: @"sourcecode.cpp.cpp"])
	{
	  [self addPath: path 
		withFileReferenceKey: pbxFileReference
		toArray: cppFiles
		type: buildPhaseType];
	}
      else if([type isEqual: @"sourcecode.c.objc"])
	{
	  [self addPath: path 
		withFileReferenceKey: pbxFileReference
		toArray: mFiles
		type: buildPhaseType];
	}
    }

  // Add arrays to the dictionary...
  [aDictionary setObject: cFiles forKey: @"c"];
  [aDictionary setObject: mFiles forKey: @"m"];
  [aDictionary setObject: cppFiles forKey: @"cpp"];
}

- (NSString *) lookupResourcesOfPbxBuildFileRef: (NSString *)pbxBuildFileRef;
{
  NSDictionary *pbxBuildFile     = [objects objectForKey: pbxBuildFileRef];
  NSString     *fileRef          = [pbxBuildFile objectForKey: @"fileRef"];
  NSDictionary *pbxFileReference = [objects objectForKey: fileRef];

  NSDebugMLog(@"Looking up file handle: %@", pbxBuildFileRef);
  
  // if the resource is localized we have a PBXVariantGroup instead of
  // PBXFileReference
  if ([[pbxFileReference objectForKey: @"isa"] 
	isEqual: @"PBXVariantGroup"])
    {
      NSEnumerator *e = [[pbxFileReference objectForKey: @"children"] 
			  objectEnumerator];
      NSString     *fileRef;
      NSString     *fileName = nil;

      NSDebugMLog(@"Got PBXVariantGroup");

      while ( (fileRef = [e nextObject]) )
	{
	  NSDictionary *pbxFileReference = [objects objectForKey: fileRef];
	  NSString     *path             = [pbxFileReference 
					     objectForKey: @"path"];
	  if (fileName != nil && 
	      !([[path lastPathComponent] isEqual: fileName]) )
	    NSLog(@"Warning: Got multiple file names for Resource: %@, %@", 
		  [path lastPathComponent], fileName);

	  fileName = [path lastPathComponent];

	  // we are only interested in the Language
	  // now it is in the form Korean.lproj/iTerm.strings
	  path = [path stringByDeletingLastPathComponent];
	  // Korean.lproj
	  path = [path stringByDeletingPathExtension];
	  // Korean
	  [languages addObject: path];
	}
      NSDebugMLog(@"Finished processing localized Resource: %@", fileName);
      NSDebugMLog(@"Available languages: %@", [languages description]);
      [localizedResources addObject: fileName];
	// return nil here, because we add the files to other arrays
      return nil;
    }
  return [pbxFileReference objectForKey: @"path"];
}

- (void) retrieveFileListFromBuildPhase: (NSDictionary *)buildPhase
		       andStoreResultIn: (NSMutableArray *)anArray
{
  NSArray      *files          = [buildPhase objectForKey: @"files"];
  NSString     *buildPhaseType = [buildPhase objectForKey: @"isa"];
  NSEnumerator *e              = [files objectEnumerator];
  NSString     *pbxBuildFile;

  NSDebugMLog(@"Adding files for buildPhase: %@", buildPhaseType);

  if ([buildPhaseType isEqual: @"PBXResourcesBuildPhase"])
    {
      while ( (pbxBuildFile = [e nextObject]) )
	 {
	  NSDebugMLog(@"Looking up resource file handle: %@", pbxBuildFile);
	  NSDictionary *ref     = [objects objectForKey: pbxBuildFile]; 
	  NSString     *refType = [ref objectForKey: @"isa"];
	  NSString     *path;

	  if ([refType isEqual: @"PBXBuildFile"])
	    {
	      NSString *pbxFileReference = 
		[[objects objectForKey: pbxBuildFile] 
 		  objectForKey: @"fileRef"];

	      path = [self lookupResourcesOfPbxBuildFileRef: pbxBuildFile]; 
	      // path == nil means that lookupResourcesOfPbxBuildFileRef
	      // found a localized resource which is added to
	      // the localized resource fields by the method itself
	      [self              addPath: path 
		    withFileReferenceKey: pbxFileReference
				 toArray: anArray
				    type: buildPhaseType];
	    }
	  else
	    {
	      NSLog(@"Warning: Expected 'PBXBuildFile', got: '%@'", 
  		    refType); 
	      continue;
	    }
	}
    }
  else
    while ( (pbxBuildFile = [e nextObject]) )
      {
	NSString *pbxFileReference = 
	  [[objects objectForKey: pbxBuildFile] 
	    objectForKey: @"fileRef"];

	NSDebugMLog(@"Looking up file handle: %@", pbxBuildFile);
	NSString *path = [self lookupResourcesOfPbxBuildFileRef: pbxBuildFile];
	[self              addPath: path 
	      withFileReferenceKey: pbxFileReference
			   toArray: anArray
			      type: buildPhaseType];
      }
}

- (void)              addPath: (NSString *)path 
         withFileReferenceKey: (NSString *)fHandle 
                      toArray: (NSMutableArray *)anArray
			 type: (NSString *)type
{
 if (path != nil)
    {
      NSString *sourceTree = [[objects objectForKey: fHandle] 
			       objectForKey: @"sourceTree"];

      if ([sourceTree isEqual: @"<group>"])
	{
	  NSString *groupPath = 
	    [project groupPathForFileReferenceKey: fHandle];

	  if ([type isEqual: @"PBXHeadersBuildPhase"])
	    {
	      NSString *dir = [path stringByDeletingLastPathComponent];
	      if (![dir isEqual: @""])
		[headerNonGroupDirs addObject: dir];
	    }

	  if (groupPath != nil)
	    {
	      // adding path components of group path to include dirs
	      if (![type isEqual: @"PBXResourcesBuildPhase"])
		[self addPathComponentsToIncludeDirs: 
			[[[groupPath stringByAppendingPathComponent: path]
			   stringByDeletingLastPathComponent]
			  pathComponents]];

	      NSDebugMLog(@"Adding file with group Path '%@': %@", 
			 groupPath,
			 path);
	      [anArray addObject: 
			 [groupPath 
			   stringByAppendingPathComponent: path]];
	    }
	  else 
	    {
	      NSDebugMLog(@"Adding file with Path '%@'", path);
	      if([[path pathComponents] count] > 1)
		[self addPathComponentsToIncludeDirs: 
			[[path stringByDeletingLastPathComponent]
			  pathComponents]];
	      if([anArray containsObject: path] == NO)
		{
		  [anArray addObject: path];
		}
	    }
	}
      else if ([sourceTree isEqual: @"SOURCE_ROOT"]) 
	{
	  NSString *newPath = [@"./" stringByAppendingPathComponent: path];

	  [self addPathComponentsToIncludeDirs: 
		  [[path stringByDeletingLastPathComponent]
		    pathComponents]];

	  NSDebugMLog(@"Adding file with SOURCE_ROOT-path: %@", newPath);
	  [anArray addObject: path];
	}
      else if ([sourceTree isEqual: @"<absolute>"])
	{
	  NSDebugMLog(@"Adding file with absolute path: %@", path);
	  [anArray addObject: path];
	}
      else if ([sourceTree isEqual: @"BUILT_PRODUCTS_DIR"])
	; // FIXME: No support for Products yet.
          // put all the built products into one dir and symlink it
          // into all the subprojects
    }
}

@end

@implementation PBPbxNativeTarget
- (PBPbxNativeTarget *) initWithProject: (PBPbxProject *)aproject
			      andTarget: (NSDictionary *)atarget
			  withTargetKey: (NSString *)atargetKey
{
  BOOL success = NO;
  
  self = [super init];
  ASSIGN(self->project, aproject);
  ASSIGN(self->objects, [project objects]);
  RETAIN(atarget);
  ASSIGN(self->targetKey, atargetKey);

  ASSIGN(includeDirs,        [NSMutableSet     setWithCapacity: 5 ]);
  ASSIGN(headers,            [NSMutableArray arrayWithCapacity: 50]);
  ASSIGN(headerNonGroupDirs, [NSMutableSet     setWithCapacity: 5]);
  ASSIGN(sources,            [NSMutableDictionary dictionary]);
  ASSIGN(resources,          [NSMutableArray arrayWithCapacity: 10]);
  ASSIGN(languages,          [NSMutableSet     setWithCapacity: 5 ]);
  ASSIGN(localizedResources, [NSMutableArray arrayWithCapacity: 5 ]);
  ASSIGN(frameworks,         [NSMutableArray arrayWithCapacity: 5 ]);
  ASSIGN(targetDependencies,       [NSMutableArray arrayWithCapacity: 5 ]);

  // set up include dirs  
  [self setUpIncludeDirsForTarget: atarget];

  // raverse the build phases
  success = [self traverseBuildPhasesOfTarget: atarget];

  // store the dependency keys
  ASSIGN(dependencyKeys, [atarget objectForKey: @"dependencies"]);

  RELEASE(atarget);
  if (success == YES)
    return self;
  else
    {
      RELEASE(self);
      return nil;
    }
}

- (void) resolveDependencyKeys
{
  NSEnumerator *e;
  NSString     *dependencyKey;

  e = [dependencyKeys objectEnumerator];
  while ( (dependencyKey = [e nextObject]) )
    {
      NSDictionary *pbxTargetDependency = 
	[objects objectForKey: dependencyKey];
      NSString *aTargetKey = [pbxTargetDependency objectForKey: @"target"];
      NSEnumerator *t = [[project targets] objectEnumerator];
      PBPbxNativeTarget *target;

      while ( (target = [t nextObject]) )
	{
	  if ([[target targetKey] isEqual: aTargetKey])
	    {
	      [targetDependencies addObject: target];
	    }
	}
    }
}

- (NSComparisonResult) compareDepends: (PBPbxNativeTarget *)anotherTarget
{
  // if this is dependent on anotherTarget then it is considered greater
  if ([targetDependencies containsObject: [anotherTarget targetKey]])
    return NSOrderedDescending;
  // if anotherTarget is dependant on this target than anotherTarget is greater
  else if ([[anotherTarget targetDependencies] containsObject: self])
    return NSOrderedAscending;
  else 
    return NSOrderedSame;
}

- (BOOL) isEqual: (id)anObject
{
  if (self == anObject)
    return YES;
  if (![anObject isKindOfClass: [PBPbxNativeTarget class]])
    return NO;
  if ([[self targetKey] isEqual: [anObject targetKey]])
    return YES;
  else
    return NO;
}

- (NSString *) targetKey
{
  return AUTORELEASE(RETAIN(targetKey));
}

- (NSString *) targetName
{
  return AUTORELEASE(RETAIN(targetName));
}

- (NSString *) targetNameReplacingSpaces
{
  return [targetName stringByReplacingString: @" " 
		     withString: @"_"];
}

- (NSString *) targetType
{
  return AUTORELEASE(RETAIN(targetType));
}

- (NSString *) infoPlist
{
  return AUTORELEASE(RETAIN(infoPlist));
}

- (NSString *) infoPlistFile
{
  return AUTORELEASE(RETAIN(infoPlistFile));
}

- (NSString *) productVersion
{
  return AUTORELEASE(RETAIN(productVersion));
}

- (NSMutableSet *) includeDirs
{
  return AUTORELEASE(RETAIN(includeDirs));
}

- (NSMutableArray *) headers
{
  return AUTORELEASE(RETAIN(headers));
}

- (NSMutableSet *) headerNonGroupDirs;
{
  return AUTORELEASE(RETAIN(headerNonGroupDirs));
}

- (NSMutableDictionary *) sources
{
  return AUTORELEASE(RETAIN(sources));
}

- (NSMutableSet *) languages
{
  return AUTORELEASE(RETAIN(languages));
}

- (NSMutableArray *) resources
{
  return AUTORELEASE(RETAIN(resources));
}

- (NSMutableArray *) localizedResources
{
  return AUTORELEASE(RETAIN(localizedResources));
}

- (NSMutableArray *) frameworks
{
  return AUTORELEASE(RETAIN(frameworks));
}

- (NSMutableSet *) targetDependencies
{
  return AUTORELEASE(RETAIN(targetDependencies));
}


- (NSString *) description 
{
  NSEnumerator       *e;
  PBPbxNativeTarget  *target;
  NSMutableString    *result = [NSMutableString string];

  [result appendString: @"\n\nTargetName:\n"];
  [result appendString: targetName];
  [result appendString: @"\n\nTargetType:\n"];
  [result appendString: targetType];
  [result appendString: @"\n\nTarget Product Version:\n"];
  [result appendString: productVersion];
  [result appendString: @"\n\n Info-Plist:\n"];
  [result appendString: [infoPlist description]];

  [result appendString: @"\n\nHeaders:\n"];
  [result appendString: [headers description]];
  [result appendString: @"\n\nSources:\n"];
  [result appendString: [sources description]];
  [result appendString: @"\n\nLanguages:\n"];
  [result appendString: [languages description]];
  [result appendString: @"\n\nResources:\n"];
  [result appendString: [resources description]];
  [result appendString: @"\n\nLocalized Resources:\n"];
  [result appendString: [localizedResources description]];
  [result appendString: @"\n\nFrameworks:\n"];
  [result appendString: [frameworks description]];

  [result appendString: @"\n\nTargetDependencies:\n"];
  e = [targetDependencies objectEnumerator];
  while ( (target = [e nextObject]) )
    [result appendFormat: @"%@.%@", [target targetName], [target targetType]];

  return result;
}

- (void) dealloc
{
  DESTROY(targetDependencies);
  DESTROY(dependencyKeys);  
  DESTROY(frameworks);
  DESTROY(localizedResources);
  DESTROY(languages);
  DESTROY(resources);
  DESTROY(sources);
  DESTROY(headerNonGroupDirs);
  DESTROY(headers);
  DESTROY(includeDirs);
  DESTROY(infoPlist);
  DESTROY(infoPlistFile);
  DESTROY(productVersion);
  DESTROY(targetType);
  DESTROY(targetName);
  DESTROY(targetKey);
  DESTROY(project);
  DESTROY(objects);
  [super dealloc];
}
@end
