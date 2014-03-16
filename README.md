### Ruby PWA

The ruby-pwa package is a very flexible Partial Wave Analysis software package. It is written in the Ruby language; however, it contains a number of C++ extensions that do all of the heavy lifting. It also utilizes XML for all of its IO needs.

The majority of the code was written by Mike Williams with the exception of the normalization integral generator which was written by Mike McCracken(based on an earlier version by Doug Applegate). Matt Bellisis also a major contributor to the package. So, if you have problems with normalization integral generation, contact Mike McCracken, otherwise, contact Mike Williams.

Mike Bellis http://www-meg.phys.cmu.edu/~bellis

### Original Source Code

http://www-meg.phys.cmu.edu/~williams/wiki-ruby-pwa/index.php/Download_and_Install

### Modified to make it compiles on osx 10.9.2

### The original README

```
******* README file for ruby-pwa package *******

There are only a few items that are new to the ruby-pwa package in 
revision 17.  They are as follows:

1) ALL .so files are now built from the pwa/src directory.

2) Machine-specific versions of these shared objects are build and placed
in the pwa/lib/(OS_NAME)/ directories.

3) In order for this build scheme to work properly, the onvironment variable 
OS_NAME needs to be set by a user's .cshrc or likewise.  You will notice that
the pwa/lib/ directory contains the LinuxRHEL5 and Linux64RHEL5 directories.  
These are merely examples.

Enjoy the new code!

-The CMU PWA Group
```