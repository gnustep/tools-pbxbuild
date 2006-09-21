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

#ifndef _PBDEVELOPMENTHELPER_H_
#define _PBDEVELOPMENTHELPER_H_

#include <Foundation/Foundation.h>

@interface PBDevelopmentHelper : NSObject
{

}

// Developing, Logging and Debugging
/**
 * Writes the explanation and the classname of an Object 
 * to the debug log
 */
+ (void) describeClassOfObject: (id)anObject 
                   explainedBy: (NSString *)explanation;

/**
 * If anObject is a [NSDictionary] or an [NSArray], enumerate its keys,
 * look them up in aDictionary and print the key and the description
 * of the lookup to the debug log
 */
+ (void) enumerateObject: (id)anObject 
            inDictionary: (id)aDictionary 
             explainedBy: (NSString *)explanation;
/**
 * This iterates over anArray, looks up the array entries in objects
 * and writes the description of the result object to the debug log
 */
+ (void) lookupArrayEntries: (NSArray *)anArray 
 	       inDictionary: (NSDictionary *)aDictionary
		explainedBy: (NSString *)explanation;

@end

#endif // _PBDEVELOPMENTHELPER_H_

