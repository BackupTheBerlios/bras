## The following line is edited by my ship script to contain the true
## version I am shipping from cvs. (kir) $Revision: 1.3 $, $Date: 1998/08/11 10:26:14 $
%define VERSION 77.66.55

Summary: Rule based command execution (ala make), all written in Tcl
Name: bras
Version: %VERSION
Release: 0
Copyright: GPL
Group: Development/Building
Source: somewhere/bras-%{VERSION}.tar.gz
URL: http://wsd.iitb.fhg.de/~kir/brashome
Packager: Harald Kirsch (kir@iitb.fhg.de)

Requires: tcl


BuildRoot: /tmp/bras-rpmbuild

%description
The program bras performs rule based command execution (similar
to `make'). It is written in Tcl and its rule files are also pure
Tcl. It knows several types of rules (Newer, Always, Exist,
DependsFile) and allows to implement more types easily. Additionally
it does not break the chain of reasoning (like make does) when it
works in several directories.

%prep
%setup

%build
## All we have to do is run latex on the docs
cd doc
latex bras.tex 
latex bras.tex 
latex bras.tex 
dvips -o bras.ps bras.dvi


%install
## There is an install script which understands a prefix ala configure
mkdir -p $RPM_BUILD_ROOT/usr/bin
mkdir -p $RPM_BUILD_ROOT/usr/man/man1
mkdir -p $RPM_BUILD_ROOT/usr/doc

export RPM_BUILD_ROOT
./install.wish $RPM_BUILD_ROOT/usr/lib/bras-%{VERSION} $RPM_BUILD_ROOT/usr

%post
## Fix the path to the tclsh
# Actually I would like to do the following, but is does not work due
# to rpms database locking (stupid)
# TCLSH=#\!`rpm -ql tcl|grep /tclsh$`
TCLSH=#\!`which tclsh`
p=/usr/lib/bras-%{VERSION}
cp $p/bras $p/bras.orig
sed -e "1s,.*,$TCLSH,"  $p/bras.orig >$p/bras
rm $p/bras.orig




%files
%attr(-,root,root) %doc doc/bras.ps
%attr(-,root,root) %doc README
%attr(-,root,root) %doc CHANGES
%attr(-,root,root) %doc doc/bras.tex

%attr(-,root,root) /usr/bin/bras
%attr(-,root,root) /usr/man/man1/bras.1

%attr(-,root,root) %dir /usr/lib/bras-%{VERSION}

%attr(-,root,root) /usr/lib/bras-%{VERSION}/bras
%attr(-,root,root) /usr/lib/bras-%{VERSION}/alwaysRule.tcl
%attr(-,root,root) /usr/lib/bras-%{VERSION}/brasUtils.tcl
%attr(-,root,root) /usr/lib/bras-%{VERSION}/consider.tcl
%attr(-,root,root) /usr/lib/bras-%{VERSION}/defaultCmd.tcl
%attr(-,root,root) /usr/lib/bras-%{VERSION}/defrule.tcl
%attr(-,root,root) /usr/lib/bras-%{VERSION}/dependsFileRule.tcl
%attr(-,root,root) /usr/lib/bras-%{VERSION}/evalCmds.tcl
%attr(-,root,root) /usr/lib/bras-%{VERSION}/existRule.tcl
%attr(-,root,root) /usr/lib/bras-%{VERSION}/lastMinuteRule.tcl
%attr(-,root,root) /usr/lib/bras-%{VERSION}/newerRule.tcl
%attr(-,root,root) /usr/lib/bras-%{VERSION}/sourceDeps.tcl
%attr(-,root,root) /usr/lib/bras-%{VERSION}/rules.Linux
%attr(-,root,root) /usr/lib/bras-%{VERSION}/rules.SunOS
%attr(-,root,root) /usr/lib/bras-%{VERSION}/bras.1
%attr(-,root,root) /usr/lib/bras-%{VERSION}/README
%attr(-,root,root) /usr/lib/bras-%{VERSION}/bras.ps
%attr(-,root,root) /usr/lib/bras-%{VERSION}/bras.tex
%attr(-,root,root) /usr/lib/bras-%{VERSION}/Brasfile

