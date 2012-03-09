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

#include "PBMakefileGenerator.h"
#include <Foundation/NSFileManager.h>

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
 * insert the CFLAGS entry for the compiler
 */
- (void) insertCFlagsForTarget: (PBPbxNativeTarget *)target
					inMakefile: (NSMutableString *)makefile;

/**
 * insert the shell scripts into before-all::
 */
- (void) createShellScriptEntriesForTarget: (PBPbxNativeTarget *)target
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

- (void) insertCFlagsForTarget: (PBPbxNativeTarget *)target
                    inMakefile: (NSMutableString *)makefile
{
  NSString * targetcflags = [[target buildSettings] objectForKey: @"OTHER_CFLAGS"];
	
  NSString * cflags = [NSString stringWithFormat: @"\n\nADDITIONAL_CPPFLAGS+= -DGNUSTEP %@", targetcflags == nil ? @"" : targetcflags];
	
  /* C Dialect START */
  NSString * gccCLanguageStandard = [[target buildSettings] objectForKey: @"GCC_C_LANGUAGE_STANDARD"];
  if(gccCLanguageStandard)
    {
      cflags = [cflags stringByAppendingFormat: @" -std=%@",gccCLanguageStandard];
    }
  /* C Dialect END */
	
  /* Optimization Level START */
  NSString * gccOptimizationLevel = [[target buildSettings] objectForKey: @"GCC_OPTIMIZATION_LEVEL"];
  if(gccOptimizationLevel)
    {
      cflags = [cflags stringByAppendingFormat: @" -O%@", gccOptimizationLevel];
    }
  /* Optimization Level END */

  cflags = [cflags stringByAppendingString: @"\n"];
	
  [makefile appendString:cflags];
}

-(NSArray*)includeDirectoriesForDepencies: (PBPbxNativeTarget *)target 
{
  if ([[target targetDependencies] count] == 0)
    return nil;
	
  NSEnumerator		*e          = [[target targetDependencies] objectEnumerator];	
  NSMutableArray	*nativeLibs = [NSMutableArray arrayWithCapacity:[[target targetDependencies] count]];
  PBPbxNativeTarget	*dependency;
  
  while ( (dependency = [e nextObject]) )
    {
      if ([[dependency targetType] isEqual: @"framework"])
        {
          NSString *libDir;
          libDir = [@".." stringByAppendingPathComponent:[self getSubprojectNameForTarget: dependency]];
          
          [nativeLibs addObject:libDir];
        }
    }
  return nativeLibs;
}

- (void) insertIncludeDirsForTarget: (PBPbxNativeTarget *)target
			 inMakefile: (NSMutableString *)makefile
{
  NSEnumerator *e = [[target includeDirs] objectEnumerator];
  NSString     *includeDir;

  if ([[target includeDirs] count] == 0)
    return;

  NSString     *tName = [target targetNameReplacingSpaces];      
  NSString     *type  = [target targetType]; 

  if([type isEqual: @"tool"])
    {
      tName = [tName stringByAppendingString: @"_tool"];
    }

  [makefile appendFormat: @"\n\n%@_INCLUDE_DIRS=", tName];

  while ( (includeDir = [e nextObject]) )
    {
      NSString *root = [includeDir isAbsolutePath] ? @"/" : @".";
	  
      [makefile appendFormat: @"\\\n\t-I%@", 
                [root stringByAppendingPathComponent: includeDir]];
    }

  NSArray *frameworkSubprojects = [self includeDirectoriesForDepencies: target];
  e = [frameworkSubprojects objectEnumerator];

  while( (includeDir = [e nextObject]) )
    [makefile appendFormat: @"\\\n\t-I%@", 
	      [@"." stringByAppendingPathComponent: includeDir]];
	
  /* Library paths */
  e = [[target libraryDirs] objectEnumerator];
  [makefile appendFormat: @"\n\n%@_LIB_DIRS=", tName];
  while ( (includeDir = [e nextObject]) )
    {
      NSString *root = [includeDir isAbsolutePath] ? @"/" : @".";
      [makefile appendFormat: @"\\\n\t-L%@", [root stringByAppendingPathComponent: includeDir]];
    }
	
  // generate necessary dirs in obj
  [makefile appendString: @"\n\nbefore-all::"];
  e = [[target includeDirs] objectEnumerator];
  while ( (includeDir = [e nextObject]) )
    {
      [makefile appendFormat: 
		  @"\n\tmkdir -p ./obj/%@", 
		includeDir];
    }

  // add scripts to be executed..
  [makefile appendString: @"\n"];
  [self createShellScriptEntriesForTarget: target 
                               inMakefile: makefile];

  // if the target is a framework, make the header directories
  if ([[target targetType] isEqual: @"framework"])
    {
      NSString *nonGroupDir = nil;

      [makefile appendString: @"\n\nbefore-build-headers::"];
	
      //  Make the symlink for other projects to be able to include
      [makefile appendFormat: @"\n\tmkdir -p $(FRAMEWORK_NAME).framework/Versions/%@/Headers/",[target productVersion]];  
      [makefile appendFormat: @"\n\tif [[ -h $(FRAMEWORK_NAME) ]]; then rm $(FRAMEWORK_NAME); fi", [target productVersion]];  
      [makefile appendFormat: @"\n\tln -s $(FRAMEWORK_NAME).framework/Versions/%@/Headers $(FRAMEWORK_NAME)", [target productVersion]];  
      
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
      else if([ext isEqual: @"a"] || [ext isEqual: @"dylib"])
        {
          name = [[framework stringByDeletingPathExtension] stringByReplacingString: @"lib" withString: @""];
        }
		
      // Check for well known things that we already link or can't link...
      if(name == nil)
        {
          continue;
        }      
      else if([name isEqual: @"Cocoa"] || // covered by gnustep-gui and gnustep-base
	      [name isEqual: @"Carbon"] || // not available...
	      [name isEqual: @"IOKit"] || // not available...
	      [name isEqual: @"Quartz"] || // not available... 
	      [name isEqual: @"QuartzCore"] || // not available...
	      [name isEqual: @"QuickTime"] || // not available...
	      [name isEqual: @"SystemConfiguration"] ||
	      [name isEqual: @"ApplicationServices"])
        {
          // we already are linking parts of GNUstep equivalent to what's 
          // needed for the tooltype.  Also skip any other Apple specific
          // frameworks.
          continue; 
        }
      else if([name isEqual: @"JavaVM"]) // Apple's framwork which is essentially libjvm
        {
          name = @"jvm";
        }
   
      nativeLib = [NSString stringWithFormat: @"ADDITIONAL_NATIVE_LIBS+= %@\n",name];
      [makefile appendString: nativeLib]; 
    }
}

- (void) createShellScriptEntriesForTarget: (PBPbxNativeTarget *)target 
				inMakefile: (NSMutableString *)makefile
{
  NSEnumerator *e = [[target scripts] keyEnumerator];
  NSString *key = nil;
  NSString *script = nil;
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *currentPath = [fm currentDirectoryPath];
  NSString *scriptsDir = [[currentPath stringByAppendingPathComponent: @"pbxbuild"]
			   stringByAppendingPathComponent: @"scripts"];

  if ([[target scripts] count] == 0)
    return;

  // create scripts directory...
  [fm createDirectoryAtPath: scriptsDir 
                 attributes: nil];
  
  while ((key = [e nextObject]))
    {
      NSString *scriptPath = [scriptsDir stringByAppendingPathComponent: key];
      NSString *scriptPreamble = @"# Pbxbuild - Script preamble\nBUILT_PRODUCTS_DIR=.\nSRCROOT=.\nACTION=build\nTARGET_BUILD_DIR=.\nUNLOCALIZED_RESOURCES_FOLDER_PATH=./Resources\nDERIVED_FILE_DIR=./DerivedSources\n# End preamble\n";
      
      script = [scriptPreamble stringByAppendingString: 
                        [[target scripts] objectForKey: key]];
      if(script == nil)
	{
	  continue;
	}

      // replace ditto command and other mac os x specific commands
      // with equivalents...
      script = [script stringByReplacingString: @"ditto" withString: @"cp -pr"];
      
      // script...
      [script writeToFile: scriptPath
               atomically: YES];
      
      // add it to the makefile...
      [makefile appendString: [NSString stringWithFormat: @"\t-sh %@\n",
					scriptPath]]; 
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
  if([type isEqual: @"tool"])
    {
      tName = [tName stringByAppendingString: @"_tool"];
    }

  [makefile appendFormat: @"\n\n%@_NAME=%@", 
	    [type uppercaseString], tName];

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
	andPrefix: @"CC_FILES"];
  
  // Header files...
  if ([type isEqual: @"bundle"] || [type isEqual: @"framework"] || [type isEqual: @"library"])
    {
      // Get list of header files
      NSArray        *headerFilePaths = [[target headers] sortedArrayUsingSelector:@selector(compare:)];
      NSEnumerator   *e               = [headerFilePaths objectEnumerator];
      NSMutableArray *headerFiles     = [[NSMutableArray alloc] initWithCapacity: [headerFilePaths count]];
      NSMutableSet   *directories     = [[NSMutableSet alloc] initWithCapacity: [headerFilePaths count]]; //Set so we don't get duplicates
      NSString       *path;

      // Remove directory paths from them
      while( (path = [e nextObject]) )
        {
          //Remove path components 
          //TODO: Make this cross platform by using path component stuff
          NSArray * components = [path componentsSeparatedByString: @"/"];
			
          [headerFiles addObject:[components lastObject]];
          components = [components subarrayWithRange:NSMakeRange(0, [components count]-1)];
          NSString * directory = [components componentsJoinedByString: @"/"];
          // FIXME: Temporary, see todo a few lines below
          if( [directories count] == 0)
            [directories addObject: directory];
        }
	
      // XCode puts ALL public headers into the Headers directory flat, in my experiences
      [self enumerate: headerFiles
           InMakefile: makefile
	    withTargetName: tName
	    andPrefix: @"HEADER_FILES"];
		
      // So it knows where to find these headers
      //TODO: Can only specify on dir, so need to make a temp dir and copy/link them all to that
      [self enumerate:  directories
           InMakefile: makefile
	    withTargetName: tName
	    andPrefix: @"HEADER_FILES_DIR"];
      [headerFiles release];
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
  if ([[target targetDependencies] count] == 0)
    return;
	
  NSEnumerator      *e                 = [[target targetDependencies] objectEnumerator];
	
  PBPbxNativeTarget *dependency;
  NSMutableString   *additionalLibDirs = [NSMutableString string];

  NSMutableString   *nativeLibs        = [NSMutableString string];
  NSString          *objcLibs          = [NSString string];

  objcLibs = [objcLibs stringByAppendingFormat: @"\n%@_OBJC_LIBS+=", [target targetNameReplacingSpaces]];
  [additionalLibDirs appendString: @"\nADDITIONAL_LIB_DIRS="];
	
  [nativeLibs appendString: @"\nADDITIONAL_NATIVE_LIBS +="];
  
  while ( (dependency = [e nextObject]) )
    {
      if ([[dependency targetType] isEqual: @"framework"])
        {
          NSString *libDir;
          // linking the lib
          [nativeLibs appendFormat: @" %@", 
                      [dependency targetNameReplacingSpaces]];
          
          // adding the library dir
          // The path to the subproject
          libDir = [@".." stringByAppendingPathComponent:[self getSubprojectNameForTarget: dependency]];
		
          // The path of the build product (The framework wrapper)
          libDir = [libDir stringByAppendingPathComponent: [self getSubprojectNameForTarget: dependency]];
          libDir = [libDir stringByAppendingPathComponent: @"Versions"];
          libDir = [libDir stringByAppendingPathComponent: @"Current"];
          [additionalLibDirs appendFormat: @" -L%@", libDir];
        }
      else if([[dependency targetType] isEqual: @"library"])
        {
          NSString *libDir;
          libDir = [@".." stringByAppendingPathComponent:[self getSubprojectNameForTarget: dependency]];
          libDir = [libDir stringByAppendingPathComponent: @"obj"];
          [additionalLibDirs appendFormat: @" -L%@", libDir];
			  
          [nativeLibs appendFormat: @" %@", [dependency targetNameReplacingSpaces]];	  
        }
    }

  [makefile appendString: objcLibs];
  [makefile appendString: additionalLibDirs];
	
  [makefile appendString: nativeLibs];
}
@end


@implementation PBMakefileGenerator
- (id) initWithProject: (PBPbxProject *) aProject;
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
	   stringByAppendingPathExtension: [target extension]];
}

- (NSString *) generateProjectMakefile
{
  NSEnumerator      *e;
  PBPbxNativeTarget *target;
  NSMutableString   *makefile;

  // TODO: no special handling for simple projects (one target) so far.
  // if ([project isSimpleProject] == YES)
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

  [makefile appendString: @"#\n# This file generated by pbxbuild \n#\n\n"];

  if([[target targetSubtype] isEqualToString: @"static"])
    [makefile appendString: @"# Static Library\nshared=no\n\n"];

  [makefile appendString: @"include $(GNUSTEP_MAKEFILES)/common.make\n\n"];

  [self generateStandardSectionsForTarget: target
	inMakefile: makefile];      

  [self insertIncludeDirsForTarget: target inMakefile: makefile];
  [self insertFrameworkEntriesForTarget: target inMakefile: makefile];	
  [self linkDependenciesForTarget: target inMakefile: makefile];
  [self insertCFlagsForTarget:target inMakefile:makefile];
	
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
      NSString * wrapperExtension =  [[target buildSettings] objectForKey: @"WRAPPER_EXTENSION"];
      if( wrapperExtension )
        {
          [makefile appendFormat: @"\nBUNDLE_EXTENSION = .%@\n",wrapperExtension];
        }
		
      [makefile 
	appendString: @"\ninclude $(GNUSTEP_MAKEFILES)/bundle.make\n"];
    }
  else if ([@"tool" isEqual: targetType])
    {
      [makefile 
	appendString: @"\ninclude $(GNUSTEP_MAKEFILES)/tool.make\n"];
    }

  // add includes
  if([@"library" isEqual: targetType])
    {
      [makefile appendString: @"include $(GNUSTEP_MAKEFILES)/library.make\n\n"];
    }

  return makefile;
}
@end
