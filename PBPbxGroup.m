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

#include "PBPbxGroup.h"

@implementation PBPbxGroup
- (PBPbxGroup *) initWithGroupKey: (NSString *)groupKey inObjects: objects
{
  RETAIN(groupKey);
  self = [super init];
  ASSIGN(self->objects, objects);

  group = [objects objectForKey: groupKey];
  name  = [group   objectForKey: @"name" ];
  path  = [group   objectForKey: @"path" ];

  RELEASE(groupKey);

  return self;
}

- dealloc
{
  RELEASE(files);
  RELEASE(objects);  
}

- (NSString *) name
{
  return name;
}

- (BOOL) hasPath
{
  if (path != nil)
    return YES;
  else
    return NO;
}
 
- (NSString *) path
{
  return path;
}

- (void) setPath: (NSString *)newPath
{
  ASSIGN(path, newPath);
}

- (BOOL) containsFileReference: (NSString *)pbxFileReferenceKey
{
  // lazy init
  if ( files == nil )
    {
      NSEnumerator *e = [[group objectForKey: @"children"] objectEnumerator];
      NSString     *key;

      ASSIGN(files, [NSMutableSet setWithCapacity: 20]);
      while ( (key = [e nextObject]) )
	  [files addObject: key];
    }

  return [files containsObject: pbxFileReferenceKey];
}
@end
