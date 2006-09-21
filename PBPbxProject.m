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

#include "PBPbxProject.h"
#include "PBPbxGroup.h"
#include "PBDevelopmentHelper.h"

@interface PBPbxProject (Private)

/**
 * looks up the key, if a PBXGroup, create a PBPbxGroup object
 * and descend recursively into its children; if a PBXFileReference,
 * return
 */
- (void) addGroupRecursivelyByKey: (NSString *)aKey 
		       parentPath: (NSString *)parentPath;
@end

@implementation PBPbxProject (Private)
- (void) addGroupRecursivelyByKey: (NSString *)aKey
		       parentPath: (NSString *)parentPath
{
  NSString     *childGroupKey;
  NSEnumerator *e;
  NSDictionary *groupOrFile;
  NSString     *childKey;
  
  groupOrFile = [objects  objectForKey: aKey];

  e = [[groupOrFile objectForKey: @"children"] objectEnumerator];
  while ( (childKey = [e nextObject]) )
    {
      NSDictionary *child     = [objects objectForKey: childKey];
      NSString     *childType = [child   objectForKey: @"isa"];

      RETAIN(childKey);

      if ([@"PBXGroup" isEqual: childType])
	{
	  NSString *path       = [child objectForKey: @"path"      ];
	  NSString *sourceTree = [child objectForKey: @"sourceTree"];
	  NSString *newPath    = nil;

	  if ([sourceTree isEqual: @"<group>"])
	    {
	      if (parentPath != nil)
		newPath = [parentPath stringByAppendingPathComponent: path];
	      else
		newPath = path;
	    }
	  else if ([sourceTree isEqual: @"SOURCE_ROOT"])
	    newPath = [@"./" stringByAppendingPathComponent: path];
	  else if ([sourceTree isEqual: @"<absolute>"])
	    newPath = path;
	  else if ([sourceTree isEqual: @"BUILT_PRODUCTS_DIR"])
	    ; // FIXME: No support for Products yet.
	      // put all the built products into one dir and symlink it
              // into all the subprojects
	  
	  NSDebugMLog(@"Examining Group with name: '%@'", 
		     [child objectForKey: @"name"]);

	  PBPbxGroup *pbxGroup = [[PBPbxGroup alloc] 
				   initWithGroupKey: childKey
				          inObjects: objects];
	  // only save the groups with non-nil path, for those
	  // will be needed
	  if (newPath != nil)
	    {
	      if (![[pbxGroup path] isEqual: newPath])
		[pbxGroup setPath: newPath];

	      NSDebugMLog(@"Adding group '%@' with path '%@'",
			 [pbxGroup name], [pbxGroup path]);
			 
	      [groups addObject: pbxGroup];
	    }
	  else
	    RELEASE(pbxGroup);

	  [self addGroupRecursivelyByKey: childKey parentPath: newPath];
	}
      else if ([@"PBXFileReference" isEqual: childType])
	{
	  RELEASE(childKey);
	  continue;
	}
      else
	NSLog(@"Warning: Unknown reference type '%@' in PBXGroup!", childType);

      RELEASE(childKey);
    }
}

@end


@implementation PBPbxProject
- (PBPbxProject *) initWithFile: (NSString *)fileName
{
  self=[super init];
  NSDictionary      *dict = 
    [NSDictionary dictionaryWithContentsOfFile: fileName];
  NSMutableArray    *myTargets;
  NSEnumerator      *e;
  NSString          *targetKey;
  PBPbxNativeTarget *target;

  ASSIGN(version, [dict objectForKey: @"objectVersion"]);
  ASSIGN(objects, [dict objectForKey: @"objects"]);
  ASSIGN(classes, [dict objectForKey: @"classes"]);
  ASSIGN(rootObject, 
	 [objects objectForKey: [dict objectForKey: @"rootObject"]]);
  myTargets  = [rootObject objectForKey: @"targets"];

  ASSIGN(targets, [NSMutableArray arrayWithCapacity: 3]);

  // spew out the root object (the project)
  NSDebugLog([NSString stringWithFormat:
    @"rootObject class: %@", [[rootObject class] description]]);
  NSDebugMLog(@"description: ");
  NSDebugMLog([rootObject description]);

  // initialize groups
  groups = [NSMutableArray arrayWithCapacity: 10];
  RETAIN(groups);
  [self addGroupRecursivelyByKey: [rootObject objectForKey: @"mainGroup"] 
	              parentPath: nil];

  // spew out the targets
  [PBDevelopmentHelper lookupArrayEntries: myTargets 
			     inDictionary: objects
			      explainedBy: @"targets:"];
  // extract them
  e = [myTargets objectEnumerator];
  while ( (targetKey = [e nextObject]) )
    {
      NSDictionary      *target;
      PBPbxNativeTarget *newTarget;

      // since target is only a reference to the real object,
      // look it up
      target = [objects objectForKey: targetKey]; 
      newTarget = [[PBPbxNativeTarget alloc] 
		     initWithProject: self
                           andTarget: target
		       withTargetKey: targetKey];

      if (newTarget != nil)
	{
	  AUTORELEASE(newTarget);
	  [targets addObject: newTarget];
	  NSLog(@"Found Target %@", [target objectForKey: @"name"]);
	}
    }

  // wire up dependencies
  e = [targets objectEnumerator];
  while ( (target = [e nextObject]) )
    {
      [target resolveDependencyKeys];
      NSDebugMLog(@"Completed initialization for target :'%@', Description:", 
		  [target targetName]);
      NSDebugMLog([target description]);
    }

  // and sort the targets according to dependency order
  ASSIGN(targets, 
	 [targets sortedArrayUsingSelector: @selector(compareDepends:)]);

  return self;
}

-dealloc
{
  RELEASE(groups);
  RELEASE(targets);
  RELEASE(classes);
  RELEASE(rootObject);  
  RELEASE(version);
  RELEASE(objects);
}

- (BOOL) isSimpleProject
{
  unsigned int numberOfTargets = [targets count];
  NSAssert(numberOfTargets >= 1, @"The project contains no targets");

  if (numberOfTargets > 1)
    return NO;
  else
    return YES;
}

- (NSString *) groupPathForFileReferenceKey: (NSString *)pbxFileReferenceKey
{
  NSEnumerator *e = [groups objectEnumerator];
  PBPbxGroup   *group;

  while ( (group = [e nextObject]) )
      if ([group containsFileReference: pbxFileReferenceKey])
	return [group path];

  return nil;
}

- (NSArray *) targets
{
  return AUTORELEASE(RETAIN(targets));
}

- (NSDictionary *) objects 
{
  return AUTORELEASE(RETAIN(objects));
}

- (NSString *) version
{
  return AUTORELEASE(RETAIN(version));
}

@end
