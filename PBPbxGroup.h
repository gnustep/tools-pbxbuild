/*
   Project: pbxbuild

   Copyright (C) 2006 Free Software Foundation

   Author: Hans Baier,,,

   Created: 2006-08-19 04:05:41 +0200 by jack

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

#ifndef _PBPBXGROUP_H_
#define _PBPBXGROUP_H_

#include <Foundation/Foundation.h>

@interface PBPbxGroup : NSObject
{
  NSDictionary        *objects;
  NSDictionary        *group;
  NSString            *name;
  NSString            *path;
  NSMutableSet        *files;
}
/**
 * Designated Initializer: groupKey is the key of a group in the 
 * NSDictionary objects
 */
- (PBPbxGroup *) initWithGroupKey: (NSString *)groupKey inObjects: objects;

- (void) dealloc;

/**
 * getter for the name of the group
 */
- (NSString *) name;

/**
 * returns YES, if the group has an associated path
 * (which has to be prepended to the filenames in the GNUmakefile)
 * otherwise returns NO
 */
- (BOOL) hasPath;

/**
 * getter for the path of the group
 */
- (NSString *) path;

/**
 * getter for the path of the group
 */
- (void) setPath: (NSString *) newPath;

/**
 * determines whether a PBXFileReference is in the group
 */
- (BOOL) containsFileReference: (NSString *)pbxFileReferenceKey;

@end

#endif // _PBPBXGROUP_H_

