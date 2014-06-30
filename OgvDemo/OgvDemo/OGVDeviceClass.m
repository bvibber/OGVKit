//
//  OGVDeviceClass.m
//  OgvDemo
//
//  Created by Brion on 6/30/14.
//  Copyright (c) 2014 Brion Vibber. All rights reserved.
//

#import "OGVDeviceClass.h"

#include <sys/sysctl.h>
#include <mach/machine.h>

@implementation OGVDeviceClass {
    cpu_type_t cpuType;
    cpu_subtype_t cpuSubtype;
}

-(id)init
{
    self = [super init];
    if (self) {
        size_t cpuTypeSize = sizeof(cpu_type_t);
        sysctlbyname("hw.cputype", &cpuType, &cpuTypeSize, NULL, 0);
        
        size_t cpuSubtypeSize = sizeof(cpu_subtype_t);
        sysctlbyname("hw.cpusubtype", &cpuSubtype, &cpuSubtypeSize, NULL, 0);
    }
    return self;
}

-(BOOL)isSimulator
{
    return (cpuType == CPU_TYPE_X86 || cpuType == CPU_TYPE_X86_64);
}

-(BOOL)isAtLeastARMv7
{
    return (cpuType == CPU_TYPE_ARM && cpuSubtype >= CPU_SUBTYPE_ARM_V7) ||
        [self isAtLeastARM64];
}

-(BOOL)isAtLeastARMv7s
{
    return (cpuType == CPU_TYPE_ARM && cpuSubtype >= CPU_SUBTYPE_ARM_V7S) ||
        [self isAtLeastARM64];
}

-(BOOL)isAtLeastARM64
{
    return (cpuType == CPU_TYPE_ARM64);
}

@end
