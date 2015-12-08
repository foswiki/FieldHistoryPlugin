# See bottom of file for default license and copyright information

=begin TML

---+ package Foswiki::Plugins::FieldHistoryPlugin

=cut

# change the package name!!!
package Foswiki::Plugins::FieldHistoryPlugin;

# Always use strict to enforce variable scoping
use strict;
use warnings;

use Foswiki::Func    ();    # The plugins API
use Foswiki::Plugins ();    # For the API version
use Foswiki::Time    ();

# $VERSION is referred to by Foswiki, and is the only global variable that
# *must* exist in this package.  Two version formats are supported:
#
# Recommended:  Dotted triplet.  Use "v1.2.3" format for releases,  and
# "v1.2.3_001" for "alpha" versions.  The v prefix is required.
# This format uses the "declare" format
#     use version; our $VERSION = version->declare("v1.2.0");
#
# Alternative:  Simple decimal version.   Use "1.2" format for releases, and
# "1.2_001" for "alpha" versions.  Do NOT use the "v" prefix.  This style
# is set either by using the "parse" method, or by a simple assignment.
#    use version; our $VERSION = version->parse("1.20_001");  OR
#    our $VERSION = "1.20_001";   # version->parse isn't really needed
#
# To convert from a decimal version to a dotted version, first normalize the
# decimal version, then increment it.
# perl -Mversion -e 'print version->parse("4.44")->normal'  ==>  v4.440.0
# In this example the next version would be v4.441.0.
#
# Note:  Alpha versions compare as numerically lower than the non-alpha version
# so the versions in ascending order are:
#   v1.2.1_001 -> v1.2.1 -> v1.2.2_001 -> v1.2.2
#
# These statements MUST be on the same line. See "perldoc version" for more
# information on version strings.
our $VERSION = '1.0';

# $RELEASE is used in the "Find More Extensions" automation in configure.
# It is a manually maintained string used to identify functionality steps.
# You can use any of the following formats:
# tuple   - a sequence of integers separated by . e.g. 1.2.3. The numbers
#           usually refer to major.minor.patch release or similar. You can
#           use as many numbers as you like e.g. '1' or '1.2.3.4.5'.
# isodate - a date in ISO8601 format e.g. 2009-08-07
# date    - a date in 1 Jun 2009 format. Three letter English month names only.
# Note: it's important that this string is exactly the same in the extension
# topic - if you use %$RELEASE% with BuildContrib this is done automatically.
# It is preferred to keep this compatible with $VERSION. At some future
# date, Foswiki will deprecate RELEASE and use the VERSION string.
our $RELEASE = '1.0';

# Short description of this plugin
# One line description, is shown in the %SYSTEMWEB%.TextFormattingRules topic:
our $SHORTDESCRIPTION = 'Record the history of a formfield inside the topic text';

# You must set $NO_PREFS_IN_TOPIC to 0 if you want your plugin to use
# preferences set in the plugin topic. This is required for compatibility
# with older plugins, but imposes a significant performance penalty, and
# is not recommended. Instead, leave $NO_PREFS_IN_TOPIC at 1 and use
# =$Foswiki::cfg= entries, or if you want the users
# to be able to change settings, then use standard Foswiki preferences that
# can be defined in your %USERSWEB%.SitePreferences and overridden at the web
# and topic level.
#
# %SYSTEMWEB%.DevelopingPlugins has details of how to define =$Foswiki::cfg=
# entries so they can be used with =configure=.
our $NO_PREFS_IN_TOPIC = 1;

=begin TML

---++ initPlugin($topic, $web, $user) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin topic is in
     (usually the same as =$Foswiki::cfg{SystemWebName}=)

*REQUIRED*

Called to initialise the plugin. If everything is OK, should return
a non-zero value. On non-fatal failure, should write a message
using =Foswiki::Func::writeWarning= and return 0. In this case
%<nop>FAILEDPLUGINS% will indicate which plugins failed.

In the case of a catastrophic failure that will prevent the whole
installation from working safely, this handler may use 'die', which
will be trapped and reported in the browser.

__Note:__ Please align macro names with the Plugin name, e.g. if
your Plugin is called !FooBarPlugin, name macros FOOBAR and/or
FOOBARSOMETHING. This avoids namespace issues.

=cut

sub initPlugin {
    my ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2.0 ) {
        Foswiki::Func::writeWarning( 'Version mismatch between ',
            __PACKAGE__, ' and Plugins.pm' );
        return 0;
    }

    # Register the _EXAMPLETAG function to handle %EXAMPLETAG{...}%
    # This will be called whenever %EXAMPLETAG% or %EXAMPLETAG{...}% is
    # seen in the topic text.

    Foswiki::Func::registerTagHandler( 'FIELDHISTORY', \&_FIELDHISTORY );

    # Allow a sub to be called from the REST interface
    # using the provided alias
    # Foswiki::Func::registerRESTHandler( 'example', \&restExample );

    # Plugin correctly initialized
    return 1;
}

# This function simply hides the FIELDHISTORY macro
sub _FIELDHISTORY {
    my($session, $params, $topic, $web, $topicObject) = @_;
    # $session  - a reference to the Foswiki session object
    #             (you probably won't need it, but documented in Foswiki.pm)
    # $params=  - a reference to a Foswiki::Attrs object containing
    #             parameters.
    #             This can be used as a simple hash that maps parameter names
    #             to values, with _DEFAULT being the name for the default
    #             (unnamed) parameter.
    # $topic    - name of the topic in the query
    # $web      - name of the web in the query
    # $topicObject - a reference to a Foswiki::Meta object containing the
    #             topic the macro is being rendered in (new for foswiki 1.1.x)
    # Return: the result of processing the macro. This will replace the
    # macro call in the final text.

    # For example, %EXAMPLETAG{'hamburger' sideorder="onions"}%
    # $params->{_DEFAULT} will be 'hamburger'
    # $params->{sideorder} will be 'onions'
    return '';
}

=begin TML

---++ beforeSaveHandler($text, $topic, $web, $meta )
   * =$text= - text _with embedded meta-data tags_
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$meta= - the metadata of the topic being saved, represented by a Foswiki::Meta object.

This handler is called each time a topic is saved.

*NOTE:* meta-data is embedded in =$text= (using %META: tags). If you modify
the =$meta= object, then it will override any changes to the meta-data
embedded in the text. Modify *either* the META in the text *or* the =$meta=
object, never both. You are recommended to modify the =$meta= object rather
than the text, as this approach is proof against changes in the embedded
text format.

*Since:* Foswiki::Plugins::VERSION = 2.0

=cut

sub beforeSaveHandler {
    my ( $text, $topic, $web, $meta ) = @_;

    # You can work on $text in place by using the special perl
    # variable $_[0]. These allow you to operate on $text
    # as if it was passed by reference; for example:
    
    $_[0] =~ s/%FIELDHISTORY{(.*?)}%/_processMacro( $1, @_ )/ges;

    return 1;
}

sub _processMacro {
    my ( $paramString, $text, $topic, $web, $meta ) = @_;

    my %params = Foswiki::Func::extractParameters( $paramString );
    my $formatString = $params{'format'};
    my $fieldName = $params{'field'};

    my ( $oldmeta, $oldtext ) = Foswiki::Func::readTopic( $web, $topic );
    
    my $oldfieldhashref = $oldmeta->get( 'FIELD', $fieldName );
            
    my $oldValue = $oldfieldhashref ?
                   $oldmeta->get( 'FIELD', $fieldName )->{'value'} :
                   '';
                       
    my $newfieldhashref = $meta->get( 'FIELD', $fieldName );
    return "%FIELDHISTORY{$paramString}%" unless $newfieldhashref;
             
    my $newValue = $newfieldhashref ?
                   $meta->get( 'FIELD', $fieldName )->{'value'} :
                   '';
                   
    return "%FIELDHISTORY{$paramString}%" unless $newValue ne '' && $newValue ne $oldValue;
    
    $newValue =~ s/\s+$//;
     
    my $currentDate = Foswiki::Time::formatTime( time(), $Foswiki::cfg{DefaultDateFormat} );
    my $currentTime = Foswiki::Time::formatTime( time(), '$hour:$min');
    $formatString =~ s/\$date/$currentDate/;
    $formatString =~ s/\$time/$currentTime/;
    $formatString =~ s/\$wikiname/Foswiki::Func::getWikiName()/e;
    
    $formatString =~ s/\$value/$newValue/;
    $formatString =~ s/\n/<br \/>/g;
    
    $formatString = Foswiki::Func::expandVariablesOnTopicCreation($formatString);
    $formatString = Foswiki::Func::decodeFormatTokens($formatString);
    $formatString =~ s/\$macro/%FIELDHISTORY{$paramString}%/; 
 
    return $formatString;
}

1;

__END__
Foswiki - The Free and Open Source Wiki, http://foswiki.org/

Author: Kenneth Lavrsen

Copyright (C) 2008-2015 Foswiki Contributors. Foswiki Contributors
are listed in the AUTHORS file in the root of this distribution.
NOTE: Please extend that file, not this notice.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 2
of the License, or (at your option) any later version. For
more details read LICENSE in the root of this distribution.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

As per the GPL, removal of this notice is prohibited.
