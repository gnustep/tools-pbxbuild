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

#ifndef _PBMAKEFILEGENERATOR_H_
#define _PBMAKEFILEGENERATOR_H_

#include <Foundation/Foundation.h>
#include "PBPbxProject.h"


@interface PBMakefileGenerator : NSObject
{
  PBPbxProject   *project;
}
/**
 * designated initializer, aProject is the project which Makefile 
 * is to be generated
 */
- (PBMakefileGenerator *) initWithProject: (PBPbxProject *) aProject;

- (void) dealloc;

/**
 * set aProject for which a makefile should be generated
 */
- (void) setProject: (PBPbxProject *) aProject;

/**
 * returns the name of the subproject (is used for the subproject
 * directory name
 */
- (NSString *) getSubprojectNameForTarget: (PBPbxNativeTarget *)target;

/**
 * Generates the top level Makefile for the project and returns
 * the resulting makefile as a [NSString].
 * The resulting makefile is an aggregate project if the project 
 * contains more than one target and a single project if it contains
 * only one target.
 */
- (NSString *) generateProjectMakefile;

/**
 * generate the Makefile for the given target and return
 * the resulting makefile as a NSString
 */
- (NSString *) generateMakefileForTarget: (PBPbxNativeTarget *)target;
@end

#endif // _PBMAKEFILEGENERATOR_H_

