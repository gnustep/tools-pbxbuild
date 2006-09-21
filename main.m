/*
   Project: pbxbuild

   Copyright (C) 2006 Free Software Foundation

   Author: Hans Baier,,,

   Created: 2006-08-09 04:23:23 +0200 by jack

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

#include "cmdline.h"

#include <Foundation/Foundation.h>
#include "PBMakefileGenerator.h"
#include "PBPbxProject.h"

NSString *
findProjectFilename(NSArray *projectDirEntries);

/**
 * <p>This tools builds XCode-Projects by converting the project files into 
 * a directory hierarchy under <code>pbxbuild</code>, each target in the
 * original project is represented by a GNUmakefile subproject</p>
 */
int
main(int argc, const char *argv[], char *env[])
{
  PBPbxProject               *project;
  NSString                   *projectFilename;
  NSString                   *projectDir;
  NSArray                    *projectDirEntries;
  NSString                   *projectMakefile;
  PBPbxNativeTarget          *target;
  PBMakefileGenerator        *generator;
  NSString                   *makefile;
  struct gengetopt_args_info args_info;
  NSEnumerator               *e;
  NSFileManager              *fileManager;
  NSString                   *pbxbuildDir;
  NSTask                     *make;

  CREATE_AUTORELEASE_POOL(pool);
  fileManager = [NSFileManager defaultManager];

  /* let's call our cmdline parser */
  if (cmdline_parser (argc, argv, &args_info) != 0)
    {
      cmdline_parser_print_help();
      RELEASE(pool);
      exit(EXIT_FAILURE);
    }

  if (args_info.help_given)
    {
      cmdline_parser_print_help();
      RELEASE(pool);
      exit(EXIT_SUCCESS);
    }

  if (args_info.version_given)
    {
      cmdline_parser_print_version();
    }

  if (args_info.debug_given)
    {
      [[NSProcessInfo processInfo] setDebugLoggingEnabled: YES];
      NSMutableSet *debugSet = [[NSProcessInfo processInfo] debugSet];
      [debugSet addObject: @"dflt"];
    }

  // get the direntries of the current directory
  projectDir        = [fileManager currentDirectoryPath];
  projectDirEntries = [fileManager directoryContentsAtPath: projectDir];

  // get the project filename
  if (args_info.project_given) 
    projectFilename = [[NSString stringWithCString: args_info.project_arg]
			stringByAppendingPathComponent: @"project.pbxproj"];
  else
    projectFilename = findProjectFilename(projectDirEntries);

  if (projectFilename == nil || [@"" isEqual: projectFilename])
    {
      NSLog(@"No project (.xcode, .xcodeproj) found in current directory!");
      RELEASE(pool);
      exit(EXIT_FAILURE);
    }

  // initialize project model an makefile generator
  project           = [[PBPbxProject alloc] initWithFile: projectFilename];
  generator         = [[PBMakefileGenerator alloc] initWithProject: project];

  // create (overwrite) pbxbuild directory for builds
  pbxbuildDir = [[fileManager currentDirectoryPath] 
		   stringByAppendingPathComponent: @"pbxbuild"];

  if ([fileManager fileExistsAtPath: pbxbuildDir])
    {
      NSLog(@"Removing old build dir...\n");
      [fileManager removeFileAtPath: pbxbuildDir handler: nil];
    }

  [fileManager createDirectoryAtPath: pbxbuildDir attributes: nil];

  // create project makefile
  projectMakefile = [generator generateProjectMakefile];
  NSDebugLog(@"Project Makefile:\n%@\n", projectMakefile);
  [projectMakefile writeToFile: 
		     [pbxbuildDir 
		       stringByAppendingPathComponent: @"GNUmakefile"]
		   atomically: YES];

  // generate subprojects
  e = [[project targets] objectEnumerator];
  while ( (target = [e nextObject]) )
    {
      NSEnumerator *f = [projectDirEntries objectEnumerator];
      NSString   *projectDirEntry;
      NSString   *makefile;
      NSString   *targetDir = 
	[pbxbuildDir stringByAppendingPathComponent:
		       [[target targetName] 
			 stringByAppendingPathExtension: [target targetType]]];
      [fileManager createDirectoryAtPath: targetDir attributes: nil];
      
      // link all dir entries of the project directory into the target dir
      while ( (projectDirEntry = [f nextObject]) ) 
	{
	  NSString *source = 
	    [projectDir stringByAppendingPathComponent: projectDirEntry];
	  NSString *destination = 
	    [targetDir stringByAppendingPathComponent: projectDirEntry];

	  // skip existing GNUmakefiles
	  if ([projectDirEntry hasPrefix: @"GNUmakefile"])
	    continue;
					       
	  NSDebugLog(@"Creating symbolic link from '%@' to '%@'", 
		     source,
		     destination);
	  [fileManager createSymbolicLinkAtPath: destination
	  	                    pathContent: source];
	}

      // generate and write makefile
      makefile = [generator generateMakefileForTarget: target];
      NSDebugLog(@"Makefile for target: '%@':%@\n", 
		 [target targetName], 
		 makefile );
      [makefile writeToFile: 
		  [targetDir stringByAppendingPathComponent: @"GNUmakefile"]
		atomically: YES];
      // create link to Info.plist file

      if ([target infoPlistFile] != nil)
	[fileManager 
	  copyPath: 
	    [projectDir stringByAppendingPathComponent: [target infoPlistFile]]
	  toPath:    
	    [targetDir stringByAppendingPathComponent: @"Info-gnustep.plist"]
	  handler: nil];
      else // if not nil, the Info plist was in the pbxproj file
	[[target infoPlist] 
	  writeToFile: 
	    [targetDir stringByAppendingPathComponent: @"Info-gnustep.plist"] 
	  atomically: YES];
    }

  // if user wants to generate makefile only, exit here
  if(args_info.generate_makefile_only_given) 
    {
      AUTORELEASE(project);
      AUTORELEASE(generator);
      RELEASE(pool);
      exit(EXIT_SUCCESS);
    }

  // finally changedir to the pbxbuild directory and run make
  [fileManager changeCurrentDirectoryPath: @"pbxbuild"];
  make = [[NSTask alloc] init];
  [make setLaunchPath: @"make"];
  [make setArguments: [NSArray arrayWithObjects: @"-k", nil]];
  [make launch];

  RELEASE(make);
  AUTORELEASE(project);
  AUTORELEASE(generator);
  RELEASE(pool);
  
  return EXIT_SUCCESS;
}

NSString *
findProjectFilename(NSArray *projectDirEntries)
{
  NSEnumerator *e        = [projectDirEntries objectEnumerator];
  NSString     *fileName;

  while ( (fileName = [e nextObject]) )
    {
      if (   [[fileName pathExtension] isEqual: @"xcode"]
	  || [[fileName pathExtension] isEqual: @"xcodeproj"] )
	return [fileName stringByAppendingPathComponent: @"project.pbxproj"];
    }

  return nil;
}

