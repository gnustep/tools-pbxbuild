/*
   Project: pbxbuild

   Copyright (C) 2006 Free Software Foundation

   Author: Hans Baier,,,

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

#include "PBMakefileGenerator.h"

@interface PBMakefileGenerator (Private)

/**
 * insert the List of include search paths for the compiler
 */
- (void) insertIncludeDirsForTarget: (PBPbxNativeTarget *)target
			 inMakefile: (NSMutableString *)makefile;

/**
 * insert the List of framework and library entries for the compiler
 */
- (void) insertFrameworkEntriesForTarget: (PBPbxNativeTarget *)target
			      inMakefile: (NSMutableString *)makefile;

/**
 * insert the shell scripts into before-all::
 */
- (void) insertShellScriptEntriesForTarget: (PBPbxNativeTarget *)target
				inMakefile: (NSMutableString *)makefile;

/**
 * generates sources, headers, resources, etc. section for
 * the given target
 */
- (void) generateStandardSectionsForTarget: (PBPbxNativeTarget *)target
			        inMakefile: (NSMutableString *)makefile;

/**
 * generates file sections in the makefile (e.g. headers)
 */
- (void) enumerate: (NSObject *)collection
	InMakefile: (NSMutableString *)makefile
    withTargetName: (NSString *)tName
	 andPrefix: (NSString *)prefix;

/**
 * links in frameworks the target depends on
 */
- (void) linkDependenciesForTarget: (PBPbxNativeTarget *)target 
		      inMakefile: (NSMutableString *)makefile;
@end

@implementation PBMakefileGenerator (Private)
- (void) insertIncludeDirsForTarget: (PBPbxNativeTarget *)target
			 inMakefile: (NSMutableString *)makefile
{
  NSEnumerator *e = [[target includeDirs] objectEnumerator];
  NSString     *includeDir;

  if ([[target includeDirs] count] == 0)
    return;

  [makefile appendFormat: @"\n\n%@_INCLUDE_DIRS=", [target targetNameReplacingSpaces]];
  while ( (includeDir = [e nextObject]) )
    [makefile appendFormat: @"\\\n\t-I%@", 
	      [@"." stringByAppendingPathComponent: includeDir]];

  //generate necessary dirs in obj
  [makefile appendString: @"\n\nbefore-all::"];
  e = [[target includeDirs] objectEnumerator];
  while ( (includeDir = [e nextObject]) )
    {
      [makefile appendFormat: 
		  @"\n\tmkdir -p ./obj/%@", 
		includeDir];
    }
  
  // if the target is a framework, make the header directories
  if ([[target targetType] isEqual: @"framework"])
    {
      NSString *nonGroupDir = nil;

      [makefile appendString: @"\n\nbefore-build-headers::"];
      e = [[target includeDirs] objectEnumerator];
      while ( (includeDir = [e nextObject]) )
	[makefile appendFormat: 
	  @"\n\tmkdir -p $(FRAMEWORK_NAME).framework/Versions/%@/Headers/%@", 
		  [target productVersion], includeDir];  
      
      [makefile appendString: @"\n\nafter-build-headers::"];
      e = [[target headerNonGroupDirs] objectEnumerator];
      while ( (nonGroupDir = [e nextObject]) )
	{
	  NSString *prefix = [NSString stringWithFormat: 
	    @"$(FRAMEWORK_NAME).framework/Versions/%@/Headers/",
				       [target productVersion]];
				       
	  [makefile appendFormat:
	    @"\n\t(cd %@; ln -s %@/*.h .)",
		    prefix, nonGroupDir];
	}
    }
}

- (void) insertFrameworkEntriesForTarget: (PBPbxNativeTarget *)target
			      inMakefile: (NSMutableString *)makefile
{
  NSEnumerator *e = [[target frameworks] objectEnumerator];
  NSString     *frameworkFullName = nil;
    
  if ([[target frameworks] count] == 0)
    return;
  
  [makefile appendString: @"\n\n"]; 
  while ( (frameworkFullName = [e nextObject]) )
    {
      NSString *framework = [frameworkFullName lastPathComponent];
      NSString *name = nil;
      NSString *nativeLib = nil;
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

      nativeLib = [NSString stringWithFormat: @"ADDITIONAL_NATIVE_LIBS+= %@\n",name];
      [makefile appendString: nativeLib]; 
    }
}

- (void) insertShellScriptEntriesForTarget: (PBPbxNativeTarget *)target
				inMakefile: (NSMutableString *)makefile
{
  NSEnumerator *e = [[target scripts] objectEnumerator];
  NSString *script = nil;

  if ([[target scripts] count] == 0)
    return;
  
  while ( (script = [e nextObject]) )
    {
      if(script == nil)
	continue;
      [makefile appendString: script]; 
    }
}

- (void) generateStandardSectionsForTarget: (PBPbxNativeTarget *)target
			        inMakefile: (NSMutableString *)makefile
{
  NSString     *tName = [target targetNameReplacingSpaces];      
  NSString     *type  = [target targetType]; 
  NSArray      *cFiles = [[[target sources] objectForKey: @"c"] 
			   sortedArrayUsingSelector:@selector(compare:)];
  NSArray      *mFiles = [[[target sources] objectForKey: @"m"] 
			   sortedArrayUsingSelector:@selector(compare:)];
  NSArray      *cppFiles = [[[target sources] objectForKey: @"cpp"] 
			     sortedArrayUsingSelector:@selector(compare:)];
  NSArray      *mmFiles = [[[target sources] objectForKey: @"mm"] 
			    sortedArrayUsingSelector:@selector(compare:)];
  NSString     *version = [target productVersion];

  // Version and name...
  [makefile appendFormat: @"\n\n%@_NAME=%@", [type uppercaseString], tName];
  if(version != nil)
    {
      [makefile appendFormat: @"\n\nVERSION=%@", version];
    }

  if ([type isEqual: @"framework"])
    [makefile appendFormat: @"\n%@_CURRENT_VERSION_NAME = %@",
	      tName, [target productVersion]];

  // Source files...
  [self enumerate: mFiles
	InMakefile: makefile
	withTargetName: tName
	andPrefix: @"OBJC_FILES"];
  
  [self enumerate: mmFiles
	InMakefile: makefile
	withTargetName: tName
	andPrefix: @"OBJCC_FILES"];
  
  [self enumerate: cFiles
	InMakefile: makefile
	withTargetName: tName
	andPrefix: @"C_FILES"];
  
  [self enumerate: cppFiles
	InMakefile: makefile
	withTargetName: tName
	andPrefix: @"CPP_FILES"];
  
  // Header files...
  if ([type isEqual: @"bundle"] || [type isEqual: @"framework"] || [type isEqual: @"library"])
    {
      [self enumerate: [[target headers] sortedArrayUsingSelector:@selector(compare:)] 
	    InMakefile: makefile
	    withTargetName: tName
	    andPrefix: @"HEADER_FILES"];
    }
  
  // Resource files...
  [self enumerate: [[target resources] sortedArrayUsingSelector:@selector(compare:)]
	InMakefile: makefile
	withTargetName: tName
	andPrefix: @"RESOURCE_FILES"];
  
  [self enumerate: [[target localizedResources] sortedArrayUsingSelector:@selector(compare:)] 
	InMakefile: makefile
	withTargetName: tName
	andPrefix: @"LOCALIZED_RESOURCE_FILES"];
  
  [self enumerate: [[[target languages] allObjects] sortedArrayUsingSelector:@selector(compare:)] 
	InMakefile: makefile
	withTargetName: tName
	andPrefix: @"LANGUAGES"];
}

- (void) enumerate: (NSObject *)collection
	InMakefile: (NSMutableString *)makefile
    withTargetName: (NSString *)tName
	 andPrefix: (NSString *)prefix
{
  NSEnumerator *e = [(NSArray *)collection objectEnumerator];  
  NSString     *str;
  
  str = [e nextObject];
  if (str != nil)
    {
      [makefile appendFormat: @"\n\n%@_%@=", tName, prefix];
      [makefile appendFormat: @"\\\n\t%@", str];
      while( (str = [e nextObject]) )
	[makefile appendFormat: @"\\\n\t%@", str];
    }
}

- (void) linkDependenciesForTarget: (PBPbxNativeTarget *)target 
		      inMakefile: (NSMutableString *)makefile
{
  NSEnumerator      *e                 = [[target targetDependencies] 
					   objectEnumerator];
  PBPbxNativeTarget *dependency;
  NSMutableString   *additionalLibDirs = [NSMutableString string];
  NSString          *objcLibs          = [NSString string];

  if ([[target targetDependencies] count] == 0)
    return;

  objcLibs = [objcLibs stringByAppendingFormat: @"%@_OBJC_LIBS+=",
		       [target targetNameReplacingSpaces]];

  [additionalLibDirs appendString: @"\nADDITIONAL_LIB_DIRS="];

  while ( (dependency = [e nextObject]) )
    {
      if ([[dependency targetType] isEqual: @"framework"])
	{
	  NSString *libDir;
	  // linking the lib
	  objcLibs = [objcLibs stringByAppendingFormat: @" -l%@", 
			       [dependency targetNameReplacingSpaces]];
	  
	  // adding the library dir
	  // The path to the subproject
	  libDir = [@".." stringByAppendingPathComponent:
				[self getSubprojectNameForTarget: dependency]];
	  // The path of the build product (The framework wrapper)
	  libDir = [libDir stringByAppendingPathComponent: 
			     [self getSubprojectNameForTarget: dependency]];
	  libDir = [libDir stringByAppendingPathComponent: @"Versions"];
	  libDir = [libDir stringByAppendingPathComponent: @"Current"];

	  [additionalLibDirs appendFormat: @" -L%@", libDir];
	}
    }

  [makefile appendString: objcLibs];
  [makefile appendString: additionalLibDirs];
}
@end


@implementation PBMakefileGenerator
- (PBMakefileGenerator *) initWithProject: (PBPbxProject *) aProject;
{  
  self = [super init];
  [self setProject: aProject];
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

- (NSString *) generateProjectMakefile
{
  NSEnumerator      *e;
  PBPbxNativeTarget *target;
  NSMutableString   *makefile;

  // TODO: no special handling for simple projects (one target) so far.
  //if ([project isSimpleProject] == YES)
  //  return [self generateMakefileForTarget: 
  //		   [[project targets] objectAtIndex: 0]];

  // if not a simple project, create an aggregate project

  makefile = [NSMutableString string];
  [makefile appendString: @"\ninclude $(GNUSTEP_MAKEFILES)/common.make\n\n"];
  [makefile appendString: @"SUBPROJECTS = "];
  
  e = [[project targets] objectEnumerator];
  while ( (target = [e nextObject]) )
    {
      [makefile appendFormat: @"\\\n\t%@ ", 
		[self getSubprojectNameForTarget: target]];
    }

  [makefile appendString: @"\n\ninclude $(GNUSTEP_MAKEFILES)/aggregate.make"];

  return makefile;
}


- (NSString *) generateMakefileForTarget: (PBPbxNativeTarget *)target
{
  NSMutableString   *makefile   = [NSMutableString string];
  NSString          *targetType = [target targetType];

  [self generateStandardSectionsForTarget: target
	inMakefile: makefile];      

  [self insertIncludeDirsForTarget: target inMakefile: makefile];

  [self insertFrameworkEntriesForTarget: target inMakefile: makefile];

  [makefile appendString: @"\n\nADDITIONAL_CPPFLAGS+= -DGNUSTEP\n"];

  [self linkDependenciesForTarget: target inMakefile: makefile];

  if ([@"app" isEqual: targetType])
    {
      [makefile
	appendString: @"\ninclude $(GNUSTEP_MAKEFILES)/application.make\n"];
    }
  else if ([@"framework" isEqual: targetType])
    {
      [makefile 
	appendString: @"\ninclude $(GNUSTEP_MAKEFILES)/framework.make\n"];
    }
  else if ([@"bundle" isEqual: targetType])
    {
      [makefile 
	appendString: @"\ninclude $(GNUSTEP_MAKEFILES)/bundle.make\n"];
    }
  else if ([@"tool" isEqual: targetType])
    {
      [makefile 
	appendString: @"\ninclude $(GNUSTEP_MAKEFILES)/tool.make\n"];
    }

  // add includes
  [makefile appendString: @"include $(GNUSTEP_MAKEFILES)/common.make\n\n"];
  if([@"library" isEqual: targetType])
    {
      [makefile appendString: @"include $(GNUSTEP_MAKEFILES)/library.make\n\n"];
    }

  [self insertShellScriptEntriesForTarget: target inMakefile: makefile];

  return makefile;
}
@end
