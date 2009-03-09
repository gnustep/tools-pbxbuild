/*
   Project: pbxbuild

   Copyright (C) 2006, 2009 Free Software Foundation

   Author: Hans Baier, Gregory Casamento

   Created: 2006-08-09 13:27:20 +0200 by jack

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

#include "PBProjectGenerator.h"

@interface PBProjectGenerator (Private)

/**
 * insert the List of include search paths for the compiler
 */
- (void) insertIncludeDirsForTarget: (PBPbxNativeTarget *)target
			  inProject: (NSMutableDictionary *)projectDictionary;

/**
 * insert the List of framework and library entries for the compiler
 */
- (void) insertFrameworkEntriesForTarget: (PBPbxNativeTarget *)target
			       inProject: (NSMutableDictionary *)projectDictionary;

/**
 * generates sources, headers, resources, etc. section for
 * the given target
 */
- (void) generateStandardSectionsForTarget: (PBPbxNativeTarget *)target
				 inProject: (NSMutableDictionary *)projectDictionary;

@end

@implementation PBProjectGenerator (Private)
- (void) insertFrameworkEntriesForTarget: (PBPbxNativeTarget *)target
			       inProject: (NSMutableDictionary *)projectDictionary
{
  NSEnumerator *e = [[target frameworks] objectEnumerator];
  NSString     *frameworkFullName = nil;
  NSMutableArray *frameworks = [NSMutableArray array];
  NSMutableArray *libs = [NSMutableArray array];

  if ([[target frameworks] count] == 0)
    return;
  
  while ( (frameworkFullName = [e nextObject]) )
    {
      NSString *framework = [frameworkFullName lastPathComponent];
      NSString *name = nil;
      NSString *ext = [framework pathExtension];
      
      if(framework == nil)
	continue;
      
      if([ext isEqual: @"framework"])
	{
	  name = [framework stringByDeletingPathExtension];
	}
      else if([ext isEqual: @"a"])
	{
	  name = [[framework stringByDeletingPathExtension] 
		   stringByReplacingString: @"lib" withString: @""];
	}

      // Check for well known things that we already link or can't link...
      if(name == nil)
	{
	  continue;
	}      
      else if([name isEqual: @"Cocoa"] ||
	      [name isEqual: @"Carbon"] ||
	      [name isEqual: @"IOKit"] ||
	      [name isEqual: @"Quartz"] ||
	      [name isEqual: @"QuartzCore"] ||
	      [name isEqual: @"QuickTime"] ||
	      [name isEqual: @"SystemConfiguration"] ||
	      [name isEqual: @"ApplicationServices"])
	{
	  // we already are linking parts of GNUstep equivalent to what's 
	  // needed for the tooltype.  Also skip any other Apple specific
	  // frameworks.
	  continue; 
	}

      if([ext isEqual: @"framework"])
	{
	  [frameworks addObject: name];
	}
      else if([ext isEqual: @"a"])
	{
	  [libs addObject: name];
	}
    }

  if([[target targetType] isEqual: @"wrapper.application"])
    {
      [libs addObject: @"gnustep-base"];
      [libs addObject: @"gnustep-gui"];
    }
  if([[target targetType] isEqual: @"tool"])
    {
      [libs addObject: @"gnustep-base"];
    }

  [projectDictionary setObject: frameworks forKey: @"FRAMEWORKS"];
  [projectDictionary setObject: libs forKey: @"LIBRARIES"];
}

- (void) insertIncludeDirsForTarget: (PBPbxNativeTarget *)target
			  inProject: (NSMutableDictionary *)projectDictionary;
{
  [projectDictionary setObject: [[target includeDirs] allObjects]
	   forKey: @"SEARCH_HEADER_DIRS"];
}

- (void) generateStandardSectionsForTarget: (PBPbxNativeTarget *)target
			        inProject: (NSMutableDictionary *)projectDictionary
{
  NSString     *tName = [target targetNameReplacingSpaces];      
  NSString     *type  = [target targetType]; 
  NSMutableArray *otherSources = [NSMutableArray array];
  NSArray      *cFiles = [[target sources] objectForKey: @"c"];
  NSArray      *mFiles = [[[target sources] objectForKey: @"m"] sortedArrayUsingSelector:@selector(compare:)];
  NSMutableArray *resources = [[[target resources] sortedArrayUsingSelector:@selector(compare:)] mutableCopy];
  NSArray      *headers = [[target headers] sortedArrayUsingSelector:@selector(compare:)];
  NSMutableArray *localizedResources = [[[target localizedResources] sortedArrayUsingSelector:@selector(compare:)] mutableCopy];
  NSArray      *languages = [[[target languages] allObjects] sortedArrayUsingSelector:@selector(compare:)];
  NSArray      *cppFiles = [[[target sources] objectForKey: @"cpp"] sortedArrayUsingSelector:@selector(compare:)];
  NSMutableArray *nibFiles = [NSMutableArray array];
  NSEnumerator *e = [localizedResources objectEnumerator];
  id           o = nil;
  
  // collect the nib files.
  while((o = [e nextObject]) != nil)
    {
      if([[o pathExtension] isEqual: @"nib"])
	{
	  [nibFiles addObject: o];
	}
    }

  [localizedResources removeObjectsInArray: nibFiles];
  [resources removeObjectsInArray: nibFiles];
  
  [projectDictionary setObject: tName 
		     forKey: @"PROJECT_NAME"];

  if([target productVersion] != nil)
    {
      [projectDictionary setObject: [target productVersion] 
			 forKey: @"PROJECT_RELEASE"]; 
    }

  [otherSources addObjectsFromArray: cFiles];
  [otherSources addObjectsFromArray: cppFiles];

  [projectDictionary setObject: mFiles
		     forKey: @"CLASS_FILES"];
  
  [projectDictionary setObject: otherSources
		     forKey: @"OTHER_SOURCES"];

  [projectDictionary setObject: @"$(GNUSTEP_MAKEFILES)"
		     forKey: @"MAKEFILEDIR"];

  // Header files...
  if ([type isEqual: @"bundle"] || [type isEqual: @"framework"])
    {
      [projectDictionary setObject: headers forKey: @"HEADER_FILES"];
    }
  
  // Resource files...
  [projectDictionary setObject: resources
		     forKey: @"OTHER_RESOURCE"];
  
  [projectDictionary setObject: localizedResources
		     forKey: @"LOCALIZED_RESOURCES"];
  
  [projectDictionary setObject: nibFiles
		     forKey:@"INTERFACES"];
  
  [projectDictionary setObject: languages
		     forKey: @"USER_LANGUAGES"];
}

@end


@implementation PBProjectGenerator
- (PBProjectGenerator *) initWithProject: (PBPbxProject *) aProject;
{  
  self = [super init];
  if(self != nil)
    {
      [self setProject: aProject];
    }
  return self;
}


- (void) dealloc
{
  RELEASE(project);
  [super dealloc];
}

- (void) setProject: (PBPbxProject *) aProject
{
  ASSIGN(project, aProject);
}

- (NSString *) getSubprojectNameForTarget: (PBPbxNativeTarget *)target
{
  return [[target targetNameReplacingSpaces] 
	   stringByAppendingPathExtension: [target targetType]];
}

- (NSString *) generateProjectFile
{
  NSEnumerator      *e;
  PBPbxNativeTarget *target;
  NSMutableDictionary   *projectDictionary;
  NSMutableArray *subprojects = [NSMutableArray array];

  projectDictionary = [NSMutableDictionary dictionary];
  [projectDictionary setObject: @"" forKey: @"APPLICATIONICON"];
  [projectDictionary setObject: @"Aggregate" forKey: @"PROJECT_TYPE"];
  
  e = [[project targets] objectEnumerator];
  while ( (target = [e nextObject]) )
    {
      [subprojects addObject: [self getSubprojectNameForTarget: target]];
    }

  [projectDictionary setObject: subprojects forKey: @"SUBPROJECTS"];

  return [projectDictionary description];
}


- (NSString *) generateProjectForTarget: (PBPbxNativeTarget *)target
{
  NSMutableDictionary   *projectDictionary   = [NSMutableDictionary dictionary];
  NSString          *targetType = [target targetType];
  NSString          *pcType;

  /*
  if([targetType isEqual: @"app"])
    {
      pcType = @"Application";
    }
  else if([targetType isEqual: @"tool"])
    {
      pcType = @"Tool";
    }
  else if([targetType isEqual: @"framework"])
    {
      pcType = @"Framework";
    }
  else if([targetType isEqual: @"library"])
    {
      pcType = @"Library";
    }
  else if([targetType isEqual: @"bundle"])
    {
      pcType = @"Bundle";
    }
  else 
    {
      NSLog(@"Unable to determine target type.");
    }

  [projectDictionary setObject: pcType forKey: @"PROJECT_TYPE"];
  [projectDictionary setObject: @"GORM" forKey: @"APP_TYPE"];
  
  [self generateStandardSectionsForTarget: target
	inProject: projectDictionary];      
  
  [self insertIncludeDirsForTarget: target inProject: projectDictionary];
  
  [self insertFrameworkEntriesForTarget: target inProject: projectDictionary];
  */

  return [projectDictionary description];
}
@end
