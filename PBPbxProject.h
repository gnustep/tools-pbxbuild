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
}

/**
 * <em>Designated Initializer</em>: Loads the file specified by 
 * fileName, reads the pbxproj
 * file into the object and returns a fully initialized instance
 * that can be used to query information about the project 
 */
- (PBPbxProject *) initWithFile: (NSString *)fileName;

- dealloc;

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
@end

#endif // _PBPBXPROJECT_H_

