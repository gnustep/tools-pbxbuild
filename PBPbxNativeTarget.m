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
- (NSString *) standardizeTargetType: (NSString *)rawType;

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
 * This adds all path components in the given array to library paths
 * e.g. foo, bar, baz -> foo, foo/bar, foo/bar/baz
 */
- (void) addPathComponentsToLibraryDirs: (NSArray *)pathComponents;

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
 * retrieves all the files belonging to source buildPhase and stores the
 * into the dictionary.
 */
- (void) retrieveShellCommandsFromBuildPhase: (NSDictionary *)buildPhase
			    andStoreResultIn: (NSMutableDictionary *)aDictionary;

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
- (NSString *) standardizeTargetType: (NSString *)rawType
{
  if ([@"com.apple.product-type.application" isEqual: rawType])
    return @"app";
  if ([@"com.apple.product-type.framework" isEqual: rawType])
    return @"framework";
  if ([@"com.apple.product-type.tool" isEqual: rawType])
    return @"tool";
  if ([@"com.apple.product-type.bundle" isEqual: rawType])
    return @"bundle";
  if ([@"com.apple.product-type.library.dynamic" isEqual: rawType])
    {
      return @"library";
    }
  if ([@"com.apple.product-type.library.static" isEqual: rawType])
    {
      targetSubtype = @"static";
      return @"library";
    }

  if ([@"PBXApplicationTarget" isEqual: rawType])
    return @"app";
  if ([@"PBXFrameworkTarget" isEqual: rawType])
    return @"framework";
  if ([@"PBXToolTarget" isEqual: rawType])
    return @"tool";
  if ([@"PBXBundleTarget" isEqual: rawType])
    return @"bundle";

  return nil;
}

- (NSDictionary *) buildConfigurationListForTarget: (NSDictionary *) target  
{
  NSString *buildConfigurationListKey = [target objectForKey: @"buildConfigurationList"];
  if(buildConfigurationListKey == nil)
    {
      NSLog(@"Error: Could not find object for buildConfigurationList");
      return nil;
    }
  
  NSDictionary *buildConfigurationList = [objects objectForKey:buildConfigurationListKey];
  return buildConfigurationList;
}

- (NSDictionary *) defaultBuildConfigurationForTarget: (NSDictionary *) aTarget
{
  NSDictionary *buildConfigurationList = [self buildConfigurationListForTarget:aTarget];

  NSDictionary *defaultConfiguration = nil;
	
  NSEnumerator *e;
  NSString     *buildConfigurationKey;
	
  e = [[buildConfigurationList objectForKey: @"buildConfigurations" ]objectEnumerator];
  while ( (buildConfigurationKey = [e nextObject]) )
    {
      NSDictionary *buildConfiguration = [objects objectForKey: buildConfigurationKey];
      if( [[buildConfiguration objectForKey: @"name"] isEqualToString:defaultConfigurationName])
        {
          defaultConfiguration = buildConfiguration;
          break;
        }
    }
	
  return defaultConfiguration;
}

- (void) setBuildSettingsForTarget: (NSDictionary *) target  {
  if([[project version] isEqual: PBX_VERSION_TIGER]) 
    {
      NSString *key = [target objectForKey: @"productType"] ?
        [target objectForKey: @"productType"] 
        :
        [target objectForKey: @"isa"];
      
      buildSettings = [self getBuildSettingsTigerForTarget: target];    
      ASSIGN(targetType, [self standardizeTargetType: key]);
    }
  else if([[project version] isEqual: PBX_VERSION_PANTHER])
    {
      buildSettings = [target objectForKey: @"buildSettings"];
      ASSIGN(targetType, [self standardizeTargetType:[target objectForKey: @"productType"]]);
    }
  else if([[project version] isEqual: PBX_VERSION_LEOPARD])
    {
      // Seems to have the same behavior as TIGER version, where is uses a buildConfigurationList
      buildSettings = [self getBuildSettingsTigerForTarget: target];
      ASSIGN(targetType, [self standardizeTargetType:[target objectForKey: @"productType"]]);
    }
  else if([[project version] isEqual: PBX_VERSION_SNOWLEOPARD_XCODE_3_1] ||
          [[project version] isEqual: PBX_VERSION_SNOWLEOPARD_XCODE_3_2])
    {
      buildSettings = [target objectForKey: @"buildSettings"];
      if (nil == buildSettings)
        {
          buildSettings = [self getBuildSettingsTigerForTarget: target];
        }
      ASSIGN(targetType, [self standardizeTargetType: 
                                [target objectForKey: @"productType"]]);
    }
  else
    {
      NSLog(@"Unsupported project version: '%@', quitting...",[project version]);
      exit(EXIT_FAILURE);
    }
}

- (BOOL) traverseBuildPhasesOfTarget: (NSDictionary *)target
{
  NSString     *buildPhaseKey;
  NSDictionary *buildPhase;
  NSEnumerator *e;
	
  ASSIGN(targetName, [buildSettings objectForKey: @"PRODUCT_NAME"]);
  if(targetName == nil)
    {
      ASSIGN(targetName, [target objectForKey: @"name"]);
    }

	
  if(targetType == nil)
    {
      NSString *type = ([target objectForKey: @"productType"] != nil)?
	[target objectForKey: @"productType"]:[target objectForKey: @"isa"];

      NSDebugLog(@"Don't know how to handle target type: '%@', skipping...", type);
      return NO;
    }

  if([[project version] isEqual: PBX_VERSION_PANTHER])
    {
      infoPlistFile = nil;
      ASSIGN(infoPlist, [[target objectForKey: @"productSettingsXML"] 
			  propertyList]);
      
    }
  else // Tiger and above
    {
      ASSIGN(infoPlistFile, [buildSettings objectForKey: @"INFOPLIST_FILE"]);
      
      // Replace CFBundleExecutable = "${EXECUTABLE_NAME}" and CFBundleIdentifier = ${PRODUCT_NAME:identifier} 
      // with the proper values
      NSMutableDictionary * mutableInfo = [NSMutableDictionary dictionaryWithContentsOfFile:infoPlistFile];
      NSString * bundleExecutable = [mutableInfo valueForKey: @"CFBundleExecutable"];
      NSString * bundleIdentifier = [mutableInfo valueForKey: @"CFBundleIdentifier"];
      bundleExecutable = [bundleExecutable stringByReplacingString: @"${EXECUTABLE_NAME}" withString:[self targetName]];
      bundleIdentifier = [bundleIdentifier stringByReplacingString: @"${PRODUCT_NAME:identifier}" withString:[self targetName]];
      
      [mutableInfo setValue:bundleExecutable forKey: @"CFBundleExecutable"];
      [mutableInfo setValue:bundleIdentifier forKey: @"CFBundleIdentifier"];

      ASSIGN(infoPlist, [mutableInfo copy]);
    }
  
  ASSIGN(productVersion, [infoPlist objectForKey: @"CFBundleVersion"]);
  if(productVersion == nil)
    {
      productVersion = @"0";
    }
  
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

	  [self retrieveSourceFileListFromBuildPhase: buildPhase 
                                    andStoreResultIn: sources];
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
      else if ([buildPhaseType isEqual: @"PBXShellScriptBuildPhase"])
	{
	  [self retrieveShellCommandsFromBuildPhase: buildPhase
                                   andStoreResultIn: scripts];
	}
    }
  return YES;
}

- (void) setUpIncludeDirsForTarget: (NSDictionary *)target
{
  id     headerSearchPaths;
  id	librarySearchPaths;
  
  if([[project version] isEqual: PBX_VERSION_PANTHER])
    {
      headerSearchPaths = [buildSettings
			    objectForKey: @"HEADER_SEARCH_PATHS"];
      //Don't know what panther looks like so this may not be needed/usable.
      if(headerSearchPaths == nil)
        headerSearchPaths = [[project projectBuildSettings] objectForKey: @"HEADER_SEARCH_PATHS"];

      [self addPathComponentsToIncludeDirs: 
	      [headerSearchPaths pathComponents]];
    }
  else
    {
      // *SearchPaths could be an Array or String depending if there are mutliple values

      // Check target for settings first, then use project wide settings as fall back, like XCode does.
      headerSearchPaths = [buildSettings objectForKey: @"HEADER_SEARCH_PATHS"];
      if(headerSearchPaths == nil)
        headerSearchPaths = [[project projectBuildSettings] objectForKey: @"HEADER_SEARCH_PATHS"];
	  
      if( [headerSearchPaths isKindOfClass:[NSString class]])
        [self addPathComponentsToIncludeDirs: [headerSearchPaths pathComponents]];
      else 	if( [headerSearchPaths isKindOfClass:[NSArray class]])
        {
          NSEnumerator *e              = [headerSearchPaths objectEnumerator];
          NSString *path;
          while( (path = [e nextObject] ))
            [self addPathComponentsToIncludeDirs: [path pathComponents]];
        }
	  
      librarySearchPaths = [buildSettings objectForKey: @"LIBRARY_SEARCH_PATHS"];
      if(librarySearchPaths == nil)
        librarySearchPaths = [[project projectBuildSettings] objectForKey: @"LIBRARY_SEARCH_PATHS"];

      if( [librarySearchPaths isKindOfClass:[NSString class]])
        [self addPathComponentsToLibraryDirs: [librarySearchPaths pathComponents]];
      else 	if( [librarySearchPaths isKindOfClass:[NSArray class]])
        {
          NSEnumerator *e              = [librarySearchPaths objectEnumerator];
          NSString *path;
          while( (path = [e nextObject] ))
            [self addPathComponentsToLibraryDirs: [path pathComponents]];
        }
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
      NS_DURING 
        {
          [includeDirs addObject: 
                         [NSString pathWithComponents:
                                     [pathComponents subarrayWithRange: range]
                          ]];
        }
      NS_HANDLER
        {
          continue;
        }
      NS_ENDHANDLER;
    }
}

- (void) addPathComponentsToLibraryDirs: (NSArray *)pathComponents
{
  int i;

  // add all Directories in the path to the array
  for (i=0; i<[pathComponents count]; i++)
    {
      NSRange range;
      range.location = 0;
      range.length   = i+1;
      NS_DURING
        {
          [libraryDirs addObject: 
                         [NSString pathWithComponents:
                                     [pathComponents subarrayWithRange: range]
                          ]
           ];
        }
      NS_HANDLER
        {
          continue;
        }
      NS_ENDHANDLER
    }
}

- (NSDictionary *) getBuildSettingsTigerForTarget: (NSDictionary *)target
{
  NSString     *defaultConfigurationType;
  
  defaultConfigurationType = [defaultBuildConfiguration objectForKey: @"isa"];
  if (![@"XCBuildConfiguration" isEqual: defaultConfigurationType])
    {
      NSLog(@"FATAL: expected 'XCBuildConfiguration', but got '%@'",
            defaultConfigurationType);
      exit (EXIT_FAILURE);
    }
  
  return [defaultBuildConfiguration objectForKey: @"buildSettings"];
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

- (void) retrieveShellCommandsFromBuildPhase: (NSDictionary *)buildPhase
			    andStoreResultIn: (NSMutableDictionary *)aDictionary
{
  NSString *script = [buildPhase objectForKey: @"shellScript"];  
  NSString *name = [NSString stringWithFormat: @"script_%d.sh",[script hash]];

  // add script...
  [aDictionary setObject: script forKey: name];
}

- (void) retrieveSourceFileListFromBuildPhase: (NSDictionary *)buildPhase
			     andStoreResultIn: (NSMutableDictionary *)aDictionary
{
  NSArray      *files          = [buildPhase objectForKey: @"files"];
  NSString     *buildPhaseType = [buildPhase objectForKey: @"isa"];
  NSEnumerator *e              = [files objectEnumerator];
  NSString     *pbxBuildFile;
  NSMutableArray *cFiles, *mFiles, *cppFiles, *mmFiles;

  // File arrays...
  cFiles = [NSMutableArray arrayWithCapacity: 50];
  mFiles = [NSMutableArray arrayWithCapacity: 50];
  cppFiles = [NSMutableArray arrayWithCapacity: 50];
  mmFiles = [NSMutableArray arrayWithCapacity: 50];
 
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
      else if([type isEqual: @"sourcecode.cpp.objcpp"])
	{
	  [self addPath: path 
		withFileReferenceKey: pbxFileReference
		toArray: mmFiles
		type: buildPhaseType];
	}
    }

  // Add arrays to the dictionary, if they're not empty...
  if([aDictionary objectForKey: @"c"] != nil)
    {
      [cFiles addObjectsFromArray: [aDictionary objectForKey: @"c"]];
    }
  if([aDictionary objectForKey: @"m"] != nil)
    {
      [mFiles addObjectsFromArray: [aDictionary objectForKey: @"m"]];
    }
  if([aDictionary objectForKey: @"cpp"] != nil)
    {
      [cppFiles addObjectsFromArray: [aDictionary objectForKey: @"cpp"]];
    }
  if([aDictionary objectForKey: @"mm"] != nil)
    {
      [mmFiles addObjectsFromArray: [aDictionary objectForKey: @"mm"]];
    }

  [aDictionary setObject: cFiles forKey: @"c"];
  [aDictionary setObject: mFiles forKey: @"m"];
  [aDictionary setObject: cppFiles forKey: @"cpp"];
  [aDictionary setObject: mmFiles forKey: @"mm"];
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

  if ([buildPhaseType isEqual: @"PBXResourcesBuildPhase"])
    {
      while ( (pbxBuildFile = [e nextObject]) )
	 {
	  NSDictionary *ref; 
	  NSString     *refType;
	  NSString     *path;

	  NSDebugMLog(@"Looking up resource file handle: %@", pbxBuildFile);
	  ref     = [objects objectForKey: pbxBuildFile]; 
	  refType = [ref objectForKey: @"isa"];

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
    {
      while ( (pbxBuildFile = [e nextObject]) )
        {
          NSString *path;
          NSString *pbxFileReference = 
            [[objects objectForKey: pbxBuildFile] 
              objectForKey: @"fileRef"];

          NSDebugMLog(@"Looking up file handle: %@", pbxBuildFile);
          path = [self lookupResourcesOfPbxBuildFileRef: pbxBuildFile];
          NSDebugMLog(@"path: %@", path);
          [self              addPath: path 
                withFileReferenceKey: pbxFileReference
                             toArray: anArray
                                type: buildPhaseType];
        }
    }
}

- (void)              addPath: (NSString *)path 
         withFileReferenceKey: (NSString *)fHandle 
                      toArray: (NSMutableArray *)anArray
			 type: (NSString *)type
{
  if (path != nil)
    {
      NSString *sourceTree = [[objects objectForKey: fHandle] objectForKey: @"sourceTree"];
						
      if ([sourceTree isEqual: @"<group>"])
        {

          NSString *groupPath = [project groupPathForFileReferenceKey: fHandle];

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
                [self addPathComponentsToIncludeDirs: [[[groupPath stringByAppendingPathComponent: path] stringByDeletingLastPathComponent] pathComponents]];

              NSDebugMLog(@"Adding file with group Path '%@': %@", groupPath, path);
				
              [anArray addObject: [groupPath stringByAppendingPathComponent: path]];
            }
          else 
            {
              NSDebugMLog(@"Adding file with Path '%@'", path);
              if([[path pathComponents] count] > 1)
                [self addPathComponentsToIncludeDirs: [[path stringByDeletingLastPathComponent] pathComponents]];
	    
              if([anArray containsObject: path] == NO)
                {
                  [anArray addObject: path];
                }
            }
        }
      else if ([sourceTree isEqual: @"SOURCE_ROOT"]) 
        {		
          NSString *newPath = [@"./" stringByAppendingPathComponent: path];

          [self addPathComponentsToIncludeDirs: [[path stringByDeletingLastPathComponent] pathComponents]];

          NSDebugMLog(@"Adding file with SOURCE_ROOT-path: %@", newPath);
			
          [anArray addObject: path];
        }
      else if ([sourceTree isEqual: @"<absolute>"])
        {

          NSDebugMLog(@"Adding file with absolute path: %@", path);
          [anArray addObject: path];
        }
      else if ([sourceTree isEqual: @"SDKROOT"])
        {
          // On OS X this would be something under /Develeoper, but on all *nix systems
          // I know of, this would simply be /
          // TODO: add a variable for SDKROOT that defaults to "/"
          NSString *newPath = [@"/" stringByAppendingPathComponent: path];

          [self addPathComponentsToIncludeDirs: [[path stringByDeletingLastPathComponent] pathComponents]];

          NSDebugMLog(@"Adding file with SDKROOT-path: %@", newPath);
          [anArray addObject: newPath];

        }
      else if ([sourceTree isEqual: @"BUILT_PRODUCTS_DIR"])
        {
          ; // FIXME: No support for Products yet.
          // put all the built products into one dir and symlink it
          // into all the subprojects
        }
    }
}

@end

@implementation PBPbxNativeTarget

- (id) initWithProject: (PBPbxProject *)aproject
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
  ASSIGN(libraryDirs,        [NSMutableSet     setWithCapacity: 5 ]);
  ASSIGN(headers,            [NSMutableArray arrayWithCapacity: 50]);
  ASSIGN(headerNonGroupDirs, [NSMutableSet     setWithCapacity: 5]);
  ASSIGN(sources,            [NSMutableDictionary dictionary]);
  ASSIGN(resources,          [NSMutableArray arrayWithCapacity: 10]);
  ASSIGN(languages,          [NSMutableSet     setWithCapacity: 5 ]);
  ASSIGN(localizedResources, [NSMutableArray arrayWithCapacity: 5 ]);
  ASSIGN(frameworks,         [NSMutableArray arrayWithCapacity: 5 ]);
  ASSIGN(targetDependencies, [NSMutableArray arrayWithCapacity: 5 ]);
  ASSIGN(scripts,            [NSMutableDictionary dictionary]);
	
  ASSIGN(defaultConfigurationName, [[self buildConfigurationListForTarget: atarget] objectForKey: @"defaultConfigurationName"]);
  ASSIGN(defaultBuildConfiguration, [self defaultBuildConfigurationForTarget: atarget]);

  // Capture the buildSettings dictionary
  [self setBuildSettingsForTarget: atarget];

  // set up include dirs  
  [self setUpIncludeDirsForTarget: atarget];

  // Traverse the build phases
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
  return targetKey;
}

- (NSString *) targetName
{
  return targetName;
}

- (NSString *) targetNameReplacingSpaces
{
  return [targetName stringByReplacingString: @" " 
		     withString: @"_"];
}

- (NSString *) targetSubtype
{
  return targetSubtype;
}

- (NSString *) targetType
{
  return targetType;
}

- (NSDictionary *) infoPlist
{
  return infoPlist;
}

- (NSString *) infoPlistFile
{
  return infoPlistFile;
}

- (NSString *) productVersion
{
  return productVersion;
}

- (NSMutableSet *) includeDirs
{
  return includeDirs;
}

- (NSMutableSet *) libraryDirs
{
  return libraryDirs;
}

- (NSMutableArray *) headers
{
  return headers;
}

- (NSMutableSet *) headerNonGroupDirs;
{
  return headerNonGroupDirs;
}

- (NSMutableDictionary *) sources
{
  return sources;
}

- (NSMutableSet *) languages
{
  return languages;
}

- (NSMutableArray *) resources
{
  return resources;
}

- (NSMutableArray *) localizedResources
{
  return localizedResources;
}

- (NSMutableArray *) frameworks
{
  return frameworks;
}

- (NSMutableDictionary *) scripts
{
  return scripts;
}

- (NSMutableSet *) targetDependencies
{
  return targetDependencies;
}

- (NSDictionary *) buildSettings
{
  return buildSettings;
}

- (NSString *) extension
{
  NSString * extension = [[self buildSettings] valueForKey: @"WRAPPER_EXTENSION"];

  if( !extension )
    extension = [self targetType];

  return extension;
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
  DESTROY(libraryDirs);
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
