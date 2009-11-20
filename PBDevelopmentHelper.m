/*
   Project: pbxbuild

   Copyright (C) 2006 Free Software Foundation

   Author: Hans Baier,,,

   Created: 2006-08-12 03:15:00 +0200 by jack

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

#include "PBDevelopmentHelper.h"
#include "PBPbxProject.h"

@implementation PBDevelopmentHelper
// Developing, Logging and Debugging
+ (void) describeClassOfObject: (id)anObject 
                   explainedBy: (NSString *)explanation
{
  NSDebugMLog(@"%@:\n%@", explanation, [[anObject class] description]);
}
+ (void) enumerateObject: (id)anObject 
            inDictionary: (id)aDictionary 
             explainedBy: (NSString *)explanation
{
  NSEnumerator *e;
  id key;
  NSLog(@"\n\n%@:\n",explanation);
  if ([anObject isKindOfClass: [NSDictionary class]])
    e = [anObject keyEnumerator];
  if ([anObject isKindOfClass: [NSArray class]])
    e = [anObject objectEnumerator];
  while ( (key = [e nextObject]) )
    {
      NSObject *o;
      NSLog([key description]);
      o = [aDictionary objectForKey: key];
      NSLog([o description]);
    }
}
+ (void) lookupArrayEntries: (NSArray *)anArray 
	       inDictionary: (NSDictionary *)aDictionary
                explainedBy: (NSString *)explanation
{
  NSEnumerator *e=[anArray objectEnumerator];
  id           key;
  NSDebugMLog(@"\n\n%@:\n", explanation);
  while ( (key = [e nextObject]) )
    {
      NSDebugMLog(
        [[aDictionary objectForKey: key]
	  description]);  
    }
}
@end
