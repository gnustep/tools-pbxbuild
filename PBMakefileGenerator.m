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

  [makefile appendFormat: @"\n\n%@_INCLUDE_DIRS=", [target targetName]];
  while ( (includeDir = [e nextObject]) )
    [makefile appendFormat: @"\\\n\t-I%@", 
	      [@"." stringByAppendingPathComponent: includeDir]];
  
  //generate necessary dirs in obj
  [makefile appendString: @"\n\nbefore-all::"];
  e = [[target includeDirs] objectEnumerator];
  while ( (includeDir = [e nextObject]) )
    [makefile appendFormat: 
		@"\n\tmkdir -p ./obj/%@", 
	      includeDir];  
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

- (void) generateStandardSectionsForTarget: (PBPbxNativeTarget *)target
			        inMakefile: (NSMutableString *)makefile
{
  NSString     *tName = [target targetName];      
  NSString     *type  = [target targetType]; 

  [makefile appendFormat: @"\n\n%@_NAME=%@", [type uppercaseString], tName];
  
  [makefile appendFormat: @"\n\nVERSION=%@", [target productVersion]];

  if ([type isEqual: @"framework"])
    [makefile appendFormat: @"\n%@_CURRENT_VERSION_NAME = %@",
	      tName, [target productVersion]];

  // Source files
  [self      enumerate: [[target sources] 
			  pathsMatchingExtensions: 
			    [NSArray arrayWithObject: @"m"]]
	    InMakefile: makefile
	withTargetName: tName
	     andPrefix: @"OBJC_FILES"];

  [self      enumerate: [[target sources] 
			  pathsMatchingExtensions: 
			    [NSArray arrayWithObject: @"c"]]
	    InMakefile: makefile
	withTargetName: tName
	     andPrefix: @"C_FILES"];
  
  if ([type isEqual: @"bundle"] || [type isEqual: @"framework"])
    [self       enumerate: [target headers]
	       InMakefile: makefile
	   withTargetName: tName
	        andPrefix: @"HEADER_FILES"];

  [self      enumerate: [target resources]
	    InMakefile: makefile
	withTargetName: tName
	     andPrefix: @"RESOURCE_FILES"];

  [self      enumerate: [target localizedResources]
	    InMakefile: makefile
	withTargetName: tName
	     andPrefix: @"LOCALIZED_RESOURCE_FILES"];

  [self      enumerate: [target languages]
	    InMakefile: makefile
	withTargetName: tName
	     andPrefix: @"LANGUAGES"];
}

- (void) enumerate: (NSObject *)collection
	InMakefile: (NSMutableString *)makefile
    withTargetName: (NSString *)tName
	 andPrefix: (NSString *)prefix
{
  NSEnumerator *e = [collection objectEnumerator];  
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
		       [target targetName]];

  [additionalLibDirs appendString: @"\nADDITIONAL_LIB_DIRS="];

  while ( (dependency = [e nextObject]) )
    {
      if ([[dependency targetType] isEqual: @"framework"])
	{
	  // linking the lib
	  objcLibs = [objcLibs stringByAppendingFormat: @" -l%@", 
			       [dependency targetName]];
	  
	  // adding the library dir
	  // The path to the subproject
	  NSString *libDir = [@".." stringByAppendingPathComponent:
				[self getSubprojectNameForTarget: dependency]];
	  // The path of the build product (The framework wrapper)
	  libDir = [libDir stringByAppendingPathComponent: 
			     [self getSubprojectNameForTarget: dependency]];
	  libDir = [libDir stringByAppendingPathComponent: @"Versions"];
	  libDir = [libDir stringByAppendingPathComponent: @"Current"];

	  [additionalLibDirs appendFormat: @" -L%@", libDir];
	}
      else
	NSLog(@"Warning: Don't know how to handle dependency with type '%@'",
	      [dependency targetType]);
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


- dealloc
{
  RELEASE(project);
}

- (void) setProject: (PBPbxProject *) aProject
{
  ASSIGN(project, aProject);
}

- (NSString *) getSubprojectNameForTarget: (PBPbxNativeTarget *)target
{
  return [[target targetName] 
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
  [makefile appendString: @"include $(GNUSTEP_MAKEFILES)/common.make\n\n"];
  [makefile appendString: @"SUBPROJECTS = "];
  
  e = [[project targets] objectEnumerator];
  while ( (target = [e nextObject]) )
    [makefile appendFormat: @"\\\n\t%@ ", 
	      [self getSubprojectNameForTarget: target]];

  [makefile appendString: @"\n\ninclude $(GNUSTEP_MAKEFILES)/aggregate.make"];

  return makefile;
}


- (NSString *) generateMakefileForTarget: (PBPbxNativeTarget *)target
{
  NSMutableString   *makefile   = [NSMutableString string];
  NSString          *targetType = [target targetType];

  [makefile appendString: @"include $(GNUSTEP_MAKEFILES)/common.make\n\n"];

  [self generateStandardSectionsForTarget: target
	inMakefile: makefile];      

  [self insertIncludeDirsForTarget: target inMakefile: makefile];

  [makefile appendString: @"\n\nADDITIONAL_NATIVE_LIBS+= util\n"];
  [makefile appendString: @"\n\nADDITIONAL_CPPFLAGS+= -DGNUSTEP\n"];

  [self linkDependenciesForTarget: target inMakefile: makefile];

  if ([@"app" isEqual: targetType])
    [makefile
      appendString: @"\ninclude $(GNUSTEP_MAKEFILES)/application.make"];
  else if ([@"framework" isEqual: targetType])
      [makefile 
	appendString: @"\ninclude $(GNUSTEP_MAKEFILES)/framework.make"];
  else if ([@"bundle" isEqual: targetType])
    [makefile 
      appendString: @"\ninclude $(GNUSTEP_MAKEFILES)/bundle.make"];
  else if ([@"tool" isEqual: targetType])
    [makefile 
      appendString: @"\ninclude $(GNUSTEP_MAKEFILES)/tool.make"];

  return makefile;
}
@end
