/*
   Project: pbxbuild

   Copyright (C) 2006 Free Software Foundation

   Author: Hans Baier,,,

   Created: 2006-08-11 02:57:59 +0200 by jack

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

#ifndef _PBPBXPROJECT_H_
#define _PBPBXPROJECT_H_


/***** XCode for OS X Compatability
 * These macros are undefined in a standard OS X enviroment.
 * PBXBuild can actually be built from within XCode (and then create its
 * own GNUmakefule ;)
 */

#ifndef AUTORELEASE
#define AUTORELEASE(x) [x autorelease]
#endif

#ifndef RELEASE
#define RELEASE(x)		[x release]
#endif

#ifndef RETAIN
#define RETAIN(x)		[x retain]
#endif

#ifndef ASSIGN
#define ASSIGN(x, y)	(x = y)
#endif

#define DLog(format, ...) NSLog(@"%s(%i) %@", __FUNCTION__, __LINE__, [NSString stringWithFormat:format, ## __VA_ARGS__])

#ifndef NSDebugMLog
#ifdef GNUSTEP
#define NSDebugMLog(format, args...) \
  do { if (GSDebugSet(@"dflt") == YES) { \
    NSString *s = GSDebugFunctionMsg( \
      __PRETTY_FUNCTION__, __FILE__, __LINE__, \
      [NSString stringWithFormat: format, ##args]); \
    NSLog(@"%@", s); }} while (0)
#else
#define NSDebugMLog(format, args...) DLog(format, ## args)
#endif
#endif

#ifndef NSDebugLog
#ifdef GNUSTEP
#define NSDebugLog(format, args...) \
  do { if (GSDebugSet(@"dflt") == YES) \
    NSLog(format , ## args); } while (0)
#else
#define NSDebugLog(format, args...) DLog(format, ## args)
#endif
#endif

#ifndef DESTROY
#define DESTROY(x)		(x = nil)
#endif

#ifdef TARGET_OS_MAC
#define stringByReplacingString stringByReplacingOccurrencesOfString
#endif

#include <Foundation/Foundation.h>
#include "PBPbxNativeTarget.h"

@interface PBPbxProject : NSObject
{
  // global Layout of file
  NSMutableDictionary *objects;
  NSMutableDictionary *classes;
  NSMutableDictionary *rootObject;
  NSMutableString     *version;
  
  // contains an Array of PBPbxNativeTarget
  NSMutableArray      *targets;
  
  // used to resolve the group path of files
  NSMutableArray      *groups;
  
  // Default configuration to use
  NSMutableString     *defaultConfigurationName;
  
  NSDictionary        *projectBuildSettings;
}

/**
 * <em>Designated Initializer</em>: Loads the file specified by 
 * fileName, reads the pbxproj
 * file into the object and returns a fully initialized instance
 * that can be used to query information about the project 
 */
- (id) initWithFile: (NSString *)fileName;

- (void) dealloc;

/**
 * YES, if the project contains only one target,
 * NO, if the project contains more than one target
 */
- (BOOL) isSimpleProject;

/** 
 * returns the group path for a given pbxFileReferenceKey or
 * nil, if no group path exists
 */
- (NSString *) groupPathForFileReferenceKey: (NSString *)pbxFileReferenceKey;

/**
 * getter for targets
 */
- (NSArray *) targets;

/**
 * getter for objects
 */
- (NSDictionary *) objects;

/**
 * getter for version
 */
- (NSString *) version;

/**
 * getter for project wide build settings
  * I want properties in gcc or clang to be finished :(
 */
- (NSDictionary *)projectBuildSettings;

@end

#endif // _PBPBXPROJECT_H_

