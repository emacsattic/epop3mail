;;; epop3mail.el --- retrieve mail using epop3.el ("extended" pop3.el)
;;
;; Author:        Franklin Lee <flee@lehman.com>
;; Created:       11/1997
;; Keywords:      mail pop3
;; Version:       0.9.5
;;
;; Copyright (C) 1997, 1998 Franklin Lee
;;
;; This program is free software; you can redistribute it and/or modify it
;; under the terms of the GNU General Public License as published by the
;; Free Software Foundation; either version 2, or (at your option) any
;; later version.
;;
;; epop3mail.el is distributed in the hope that it will be useful, but
;; WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License along
;; with GNU Emacs; see the file COPYING.  If not, write to the Free
;; Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.
;;

;;; Commentary:

;;; {{{

;;
;; Description
;; -----------
;;
;; 'epop3mail' stands for 'extended pop3 mail'.  It uses 'pop3.el' as
;; distributed in Gnus v 5.4.65, with a bugfix patch (described below).
;; 'pop3.el' provides emacs-lisp primitives to handle a connection between
;; emacs and a pop3 server.  Also used is 'epop3.el' ("extended pop3.el"),
;; which calls on and extends the functionality of pop3.el (namely, the
;; UIDL and LIST commands in the POP3 protocol, which are not in pop3.el).
;;
;; epop3mail should be used when one gets mail from a pop3 server and
;; wishes to *leave mail on server* rather than use the default movemail
;; functionality.  Sometimes the default functionality is undesirable
;; (i.e., taking the mail down to the local machine and then deleting it
;; from the server) when, for example, one is retrieving mail using a
;; laptop on the road or from home.  In such a circumstance, it would be
;; nice to get mail from the POP3 server but also leave it there so that
;; it can be accessed when one returns to work (or retrieves from another
;; machine).
;;
;; epop3mail.el supports 'leave-mail-on-server' (the default), and also
;; supports multiple pop3 mailboxes.  Passwords and authentication schemes
;; are cached (per mailbox) by default, so you only need to enter them
;; once (the first time) during an emacs session.
;;
;; Note: an enterprising Gnus user (<jvinson@chevax.ecs.umass.edu>) has
;; tested and helped with the Gnus-compatibility.  For those wanting to
;; use this with Gnus, ignore the references to 'rmail' and note
;; references to Gnus below.
;;
;; --------------------------------------------------------------------------
;;
;; The discussion below assumes that 'epop3-leave-mail-on-server' is set
;; to 't'.  If set to 'nil', 'normal' rmail behavior (i.e., delete mail
;; from server) is maintained.  This is for backward compatibility for
;; those who don't want or need leave-mail-on-server but would like to
;; have the biff feature, or have APOP authentication, or just dislike
;; movemail on principle and want a wholly elisp solution.  (Take your
;; pick).
;;
;; When called from rmail, epop3mail first tries to get the UIDL from the
;; POP3 server and saves that information for later retrievals.  Caching
;; the UIDL data (in ~/.uidls.*) allows epop3mail to retrieve only those
;; messages which have _not_ been previously retrieved.  Without this
;; information, all messages left on the server are gotten -- which is of
;; course undesirable!  (UIDs (Unique IDs) are cached on a per-mailbox
;; basis by epop3mail, so if you have several pop3 mailboxes, you will
;; have that many ~/.uidls.* files).  If epop3mail finds that UIDL is not
;; supported by the POP3 server, it will default to retrieving all
;; messages.  (This is unfortunate, but there's no simple recourse in this
;; situation).
;;
;; epop3mail does all of this by overriding rmail.el's function
;; 'rmail-insert-inbox-text' to use the emacs lisp code rather than use
;; movemail for pop3 mail.  Since this function may be different between
;; versions of emacs, you may have to modify epop3mail's version of
;; rmail-insert-inbox-text to match your version of rmail.  (see the code
;; marked 'pop3-mail change' for the cond-clause which does the actual
;; override).
;;
;; Usage
;; -----
;; To use epop3mail, do the following:
;;
;; (0) Put the files pop3.el, epop3.el, epop3hash.el, biff-mode.el, and
;; epop3mail in your load-path, preferably byte-compiled.  You may need to
;; explicitly (load-library "cl") in order to successfully compile
;; epop3mail and epop3hash.
;;
;; If you have Gnus' pop3.el already, apply the following patch to your
;; version (this bug patch has been reported to the author).  This fixes a
;; minor problem with setting 'pop3-read-point' for subsequent parsing of
;; data returning from the pop3 server, and properly places this setting
;; inside of a (save-excursion).  Without this patch, epop3mail will
;; occasionally attempt to parse the wrong buffer, and hang.
;;
;; -----------------------------8<---- cut here ----8<-----------------------
;; *** pop3.el Mon Nov 24 21:13:48 1997
;; --- pop3.orig.el Sat Jul 19 16:39:26 1997
;; ***************
;; *** 108,117 ****
;;      (process))
;;       (save-excursion
;;         (set-buffer process-buffer)
;; !       (erase-buffer)
;; !        (setq pop3-read-point (point-min)))
;;       (setq process
;;        (open-network-stream "POP" process-buffer mailhost port))
;;       (let ((response (pop3-read-response process t)))
;;         (setq pop3-timestamp
;;  already         (substring response (or (string-match "<" response) 0)
;; --- 108,117 ----
;;      (process))
;;       (save-excursion
;;         (set-buffer process-buffer)
;; !       (erase-buffer))
;;       (setq process
;;        (open-network-stream "POP" process-buffer mailhost port))
;; +     (setq pop3-read-point (point-min))
;;       (let ((response (pop3-read-response process t)))
;;         (setq pop3-timestamp
;;          (substring response (or (string-match "<" response) 0)
;; -----------------------------8<---- cut here ----8<-----------------------
;;
;; (1) Specify the pop mailbox(es).
;;
;; Method (a) (the preferred method): add "po:user@server" to
;; 'rmail-primary-inbox-list (be sure to specify both user *and* fully
;; qualified hostname in the form user@fully-qualified-host) like this:
;;
;;    (setq rmail-primary-inbox-list
;;          '("po:me@mypopserver.domain.com"
;;            "po:m3@anotherserver.elsewhere.com"
;;            . . . ))
;;
;; This is the most flexible method.  IMPORTANT: Make sure that the '@'
;; and server.domain are included; the presence of the '@' character is
;; what causes this code to be called instead of movemail.
;;
;; Setting MAILHOST won't help here because only movemail uses the
;; MAILHOST environment variable and the purpose of epop3mail is to
;; *avoid* using an external movemail program.
;;
;; IMPORTANT: if you wish to use the 'biffing' features provided by
;; epop3mail, you *must* use method (a) above to specify your pop
;; mailboxes; otherwise the biff code won't know where to look for your
;; mailbox specifications.
;;
;;
;; Method (b): Alternatively, you can add a 'Mail:' line to the top of
;; your RMAIL file (make sure it's comma-delimited) like this:
;;
;;    BABYL OPTIONS: -*- rmail -*-
;;    Version: 5
;;    Labels:
;;    Mail: po:me@mypopserver.domain.com, po:m3@anotherserver.elsewhere.com
;;    Note: This is the header of an rmail file.
;;    Note: If you are seeing it in rmail,
;;    Note: it means the file has no messages in it.
;;
;; Method (b) will override method (a).  The same note about including '@'
;; and server/domain applies here.
;;
;; If you use method (b), you won't be able to use the 'biff' feature.
;; (maybe a future version of epop3mail / epop3-biff will be smarter about
;; this, but at the moment it's simpler to reference
;; 'rmail-primary-inbox-list').
;;
;; (2) Insure sure RMAIL doesn't use movemail for your pop mailboxes.
;; (see the override function 'rmail-insert-inbox-text' below for the
;; additional code calling 'epop3-mail' -- the mailbox name set in (1)
;; above *must* have the '@' in it to avoid using movemail.
;;
;; ALSO: if you have the following in your initialization code:
;;
;;   (setq rmail-pop-password-required t)
;;
;; take it out or comment it out.  It won't be needed; epop3mail uses
;; its own password caching (per mailbox).  Leaving it in will cause
;; rmail to ask you for the password in addition to epop3mail asking;
;; I don't know if rmail will remember it, but epop3mail will, by default.
;;
;;
;; Then add to your emacs (depending on version):
;;
;; emacs v 19.34 users:
;;   (add-hook 'rmail-mode-hook (function (lambda () (require 'epop3mail))))
;;
;; emacs v 20.2+ users:
;;   (require 'epop3mail)
;;
;; The difference above is due to rmail having changed its initialization
;; sequence between v 19.34 and v 20.2.  Note that epop3mail does a
;; (require 'rmail) if needed, so v 20.2 users need only put the above
;; line in.
;;
;;
;; Gnus users:
;;   (setq epop3-mail-package 'gnus
;;         nnmail-movemail-program 'epop3-mail
;;         nnmail-spool-file "po:user@popserver"
;;         nnmail-pop-password-required nil)
;;
;; The internal (require 'rmail) is ignored by epop3mail if the above setq
;; is performed.
;;
;;
;; Then add:
;;
;; (common to every emacs version):
;;
;;   (autoload 'epop3-mail "epop3mail"
;;     "Get mail from pop server for PO:USER@HOST and put it in TOFILE." t)
;;
;;   (autoload 'start-biff "epop3mail" "pop3 biff, unleashed" t)
;;   (autoload 'stop-biff "epop3mail" "pop3 biff, muzzled" t)
;;   (autoload 'restart-biff "epop3mail" "pop3 biff, RE-unleashed" t)
;;   (autoload 'flush-pop-passwords "epop3mail" "flush passwords" t)
;;   (autoload 'biffs-current-language "epop3mail" "what is biff talking?" t)
;;   (autoload 'biffs-last-check "epop3mail" "when did biff last check?" t)
;;   (autoload 'speak-biff! "biff-mode" "make biff speak" t)
;;
;; to your .emacs.
;;
;; You do *not* need to explicitly load pop3.el, epop3.el, or epop3hash.el.
;;
;;
;; (3) Adjust the user-settable variables to taste.
;;
;; To change the behavior of epop3mail, you can set the following
;; variables *prior* to loading or requiring epop3mail.  These are:
;;
;;     epop3-mail-package (default is 'rmail)
;;     epop3-leave-mail-on-server (default is t)
;;     epop3-password-style (default is 'cache)
;;
;;     epop3-quietly (default is nil)
;;     epop3-mail-debug (default is nil)
;;     epop3-biff-debug (default is nil)
;;     epop3-biff-absolutely-silent (default is nil)
;;     epop3-biff-show-progress (default is nil)
;;     epop3-biff-show-numbers (default is nil)
;;     epop3-biff-show-barks (default is t)
;;     epop3-biff-show-off-vocabulary (default is t)
;;     epop3-biff-show-time (default is t)
;;     epop3-biff-show-snooze (default is t)
;;     epop3-biff-differential-mode (default is nil)
;;     epop3-biff-idle-grace-seconds (default is 5)
;;     epop3-biff-linear-bark-mode (default is nil)
;;     epop3-override-pop3s-read-response (default is t)
;;     epop3-open-server-timeout (default is 60)
;;     epop3-authentication-always-use-default (default is t)
;;     epop3-authentication-default (default is 'pass)
;;     epop3-authentication-timeout-seconds (default is 3)
;;
;; These can also be set interactively via M-x set-variable.
;;
;; (Minor Relief For The Paranoid: if password caching is enabled, the
;; password cache can be flushed via 'M-x epop3-flush-password-cache').
;;
;; Try using the defaults first.  The debug variables are for when you run
;; into trouble and want to report details.
;;
;; (4) If you wish to have 'biff'-like functionality with your pop3
;; server, you can call it interactively (M-x epop3-start-biff), or from
;; your .emacs via
;;
;;     (epop3-start-biff <n> [t])
;;
;; or
;;     (start-biff <n> [t])
;;
;; where <n> is the number of minutes between polls and
;; optional 't' tells it to start with an immediate biff.
;;
;; You can stop the biffing via 'epop3-stop-biff' or 'stop-biff'.
;;
;; The start- and stop- biff commands can also be run interactively via M-x.
;;
;; If new mail is found on your pop3 server(s), the modeline will say
;; "Arf!" or an equivalent in one of many languages.  (My understanding of
;; the origin of the name 'biff' is that the original BSD Unix utility was
;; named after a dog who always barked when the mailman came.  This is
;; documented in The Jargon file.
;;
;; On dialup lines, the biff feature is a nice way to keep the connection
;; alive.
;;
;;
;; How it all works:
;;
;; The rmail function 'rmail-insert-inbox-text' is overridden by the
;; function of the same name below.  This version is from emacs 19.34.6
;; and may need to be revised to work with your version of rmail if your
;; Emacs is an earlier version than 19.34.
;;
;; If you modify 'rmail-insert-inbox-text' below to conform to your local
;; version of Rmail, be sure to add the changes marked 'pop3-mail change'
;; to it *before* the 't' cond clause (see code below).

;;
;; This has been tested on:
;; - FSF Emacs 19.34 on Solaris 2.5.1 and Windows 95
;;
;; Bug reports and suggestions are welcome -- send them to Franklin Lee
;; <flee@lehman.com>.
;;
;; Also: if you know how dogs "bark" in other languages, please let me
;; know!
;;
;; THANKS TO:
;; ==========
;; for ntemacs:
;; ------------
;;    <andrewi@harlequin.co.uk>
;;    <voelker@cs.washington.edu>
;;
;; for the original pop3.el:
;; -------------------------
;;    <ratinox@peorth.gweep.net>
;;    <rich.pieri@prescienttech.com>
;;
;; testing, ideas, && patches:
;; ---------------------------
;;    <ami@aviv.isse.gmu.edu>
;;    <christil@ifi.uio.no>
;;    <eludlam@mathworks.com>
;;    <grossjohann@ls6.cs.uni-dortmund.de>
;;    <jtobey@banta-im.com>
;;    <jvinson@chevax.ecs.umass.edu>
;;    <mwoelmer@umich.edu>
;;    <rickc@lehman.com>
;;    <ronross@colba.net>
;;    <rushing@nightmare.com>
;;    <smrushin@cca.rockwell.com>
;;    <stanton@haas.berkeley.edu>
;;    <vzell@de.oracle.com>
;;    <zappo@ultranet.com>
;;
;; any omissions in the above, I apologize, the omission was NOT intentional!
;;
;;
;; i18n of dog barks:
;; ------------------
;;
;; The credits for the i18n of dog barks have been moved to the comments
;; in the related biff-mode.el -- please see that source code.
;;
;; However, I would like to specially thank Professor Catherine Ball
;; <cball@gusun.georgetown.edu> and for her kind advice, and for her great
;; "Sounds of the World's Animals" page at
;;
;;          http://www.georgetown.edu/cball/animals/animals.html
;;
;; and also to her linguistic informants (see biff-mode.el).
;;
;;; History:
;;  --------
;;
;; 11/??/1997 versions 0.0000001 through 0.5: initial versions
;;
;; 12/21/1997 version 0.6: added dohash macro to make
;; epop3-get-unread-message-numbers more readable and cleaner
;; ("Cleanth is next to Godth!").
;;
;; 12/28/1997 version 0.7: added password and authentication-scheme
;; caching (see epop3-password-style).  added semi-coherent documentation.
;; added 'biff' features.  started i18n of biff messages.
;;
;; 01/02/1998 version 0.7.5: even more i18n. added (optional) unread
;; message count display ('epop3-biff-show-numbers')
;;
;; 01/08/1998 version 0.7.6: added spaces around 'barks' in mode line
;; (oops!).  proper placement of biff info after display of time.  minor
;; documentation fixes. added to installation notes. fixed problem(s) with
;; hash table access when in deleting-mail-from-server mode.  changed
;; pop-* variables to epop3-* variables for consistency...
;;
;; 01/09/1998 version 0.7.7: cosmetic change to `epop3-append-message-to-file'.
;; made nice to folks without standard-display-european enabled.
;; clarified biff procedures; now biff will try to display something
;; the *first* time it biffs (unless it discovers it needs to go into
;; differential mode).  previously it would only try to display something
;; on the *second* biff.  if delete-mail-after-retrieve, biff clears
;; mode-line barks.
;;
;; 01/11/1998 version 0.7.8: separated dohash macro to its own file.
;; separated biff barking to biff-mode.el (speak, biff!).  this makes
;; loading epop3mail faster for those who have epop3-biff-show-barks as
;; nil.  added biff-idle-timer logic.  added snooze logic.  eliminated
;; annoying mode-line clearing in `epop3-biff'.  eliminated annoying 'mark
;; set' message caused by `epop3-init-tables'.  started linear-bark mode.
;;
;; 01/21/1998 version 0.7.9: added epop3-biff-show-mail-string option
;; for mode line display.  Some people like to see '[Mail: 4]' with their
;; numbers.  fixed "*invalid*" modeline display error -- occurred in
;; console-mode (emacs -nw) as well as occasionally in window mode.
;;
;; 01/31/1998 version 0.8: added `inhibit-quit' processing in function
;; `epop3-idle-timed-biff'.  added `epop3-open-server-timeout'.  added
;; `epop3-overide-pop3-read-response' flag to cope with some people's
;; problems with their POP3 servers hanging in weird ways and not
;; reporting back to epop3mail (i.e., going into ga-ga land...).
;;
;; 02/15/1998 version 0.9: added preliminary Emacs v 20.2 compatibility
;; stuff from patches sent in by <smrushin@cca.rockwell.com> and
;; testing help from <mwoelmer@umich.edu> (I don't have a working
;; v 20.2 and am unlikely to have one in the near future...)
;;
;; 03/30/1998 version 0.9.1: made epop3-prompt-authentication-scheme
;; immune to mouse clicks (annoying!) and have a configurable timeout and
;; default (thanks to <christil@ifi.uio.no> for suggesting the ideas).
;; also, epop3-prompt-authentication-scheme flushes input, so you don't
;; get that annoying null password syndrome... (thanks to
;; <veco@montefiore.ulg.ac.be> for pointing out the syndrome).
;;
;; 07/25/1998 version 0.9.2: incorporated epop3-biff-hook code from
;; <jtobey@banta-im.com>.  Cool.
;;
;; 08/08/1998 version 0.9.3: incorporated Gnus compatibility stuff thanks
;; to <jvinson@chevax.ecs.umass.edu>.  Tres cool.  See references to
;; Gnus in the Usage section above.
;;
;; 08/12/1998: version 0.9.4.beta: added
;; `epop3-authentication-always-use-default' so that you can avoid
;; the "annoying" authentication query the first time for each mailbox.
;; this only is helpful when you have exactly one mailbox or all of
;; your mailboxes use the same authentication scheme.  It's been asked
;; for several times, so why not add it?
;;
;; 08/13/1998: version 0.9.4.gamma: documentation changes for jvinson's
;; review...
;;
;; 08/15/1998: version 0.9.5: oops! biff doesn't know about
;; nnmail-spool-file yet!  More fixes... now uses epop3-mailbox-list
;;
;;
;; TO-DO:
;; - better caching of uidls when biffing and show-numbers -- way too
;; much consing when building and destroying UIDL hash tables!
;; - perhaps using obarrays instead of cl-hash tables for speedth?
;; - perhaps integrate (or make an option to display) the functionality
;; of the 'reportmail' package?
;;
;;
;; <eludlam@mathworks.com> proposes:
;;
;; >> And while I'm here, why use [%3d] when displaying the number of
;; >> messages?  The extra spaces detract some from the desired effect I
;; >> think.  Now think this; make all barks occur just once, then instead of
;; >> a number, put in the number of barks as there are messages:
;;
;; >> Boj!  = one message
;; >> Woof Woof! = two messages
;; >> Bhauji Bhauji Bhauji! = 3 messages.
;; >> Gaf Gaf Gaf Gaf! + = more than 4 messages
;;
;; Maybe we gotta implement something like this:
;;
;; (defvar epop3-biff-linear-bark-mode nil
;;     "*Set this to non-nil to have Biff bark 'number of message' times.
;; If set to non-nil, this variable overrides `epop3-biff-show-numbers',
;; and enables a special horizontal-scroll hack for the mode-line.")
;;

;;; }}}

;;; Code:

;;; {{{

(eval-when-compile (or (featurep 'cl) (load "cl")))
(eval-when-compile (or (featurep 'biff-mode) (load "biff-mode")))

(or (featurep 'timer) (require 'timer))
(or (featurep 'cl) (require 'cl))
(or (featurep 'ange-ftp) (require 'ange-ftp))

(require 'pop3)
(require 'epop3)

;;; {{{ the 'dohash' macro for going through hash tables

(require 'epop3hash)

;;; }}} {{{ user-option variables which are settable via 'M-x set-variable'

(defvar epop3-mail-package 'rmail ;; jvinson
  "The mail package that epop3 uses.
Valid entries are 'rmail and 'gnus.")

(defvar epop3-mailbox-list nil)

(case epop3-mail-package
  (rmail (or (featurep 'rmail) (require 'rmail))
         (setq epop3-mailbox-list rmail-primary-inbox-list))
  (gnus (setq epop3-mailbox-list
              (if (listp nnmail-spool-file)
                  nnmail-spool-file
                (list nnmail-spool-file)))))

(defvar epop3-open-server-timeout 60
  "*Number of seconds before a timeout occurs in opening a connection.")

(defvar epop3-authentication-default 'pass
  "*Default POP3 authentication to be used.")

(defvar epop3-authentication-always-use-default t
  "*Always use 'epop3-authentication-default' and don't query.
This overrides `epop3-authentication-timeout-seconds' waiting.

Setting `epop3-authentication-timeout-seconds' to t is useful only
in when you have one mailbox to query OR all of your mailboxes
use the same authentication scheme.")

(defvar epop3-authentication-timeout-seconds  3
  "*Number of seconds before timing out on authentication question.")

(defvar epop3-override-pop3s-read-response t
  "*Non-nil if you want to override pop3.el's function; see below.")

(defvar epop3-leave-mail-on-server t
  "*Non-nil if leave mail on POP3 server; otherwise DELEtes the mail.")

(defvar epop3-password-style 'cache
  "*Valid values are: ask, cache, or nil.
ask and nil mean ask for password each time mail is retrieved.
cache means save passwords per user@host for use in subsequent retrievals.

You can flush the cached passwords (for security purposes) via
the interactive function 'epop3-flush-password-cache'")

(defvar epop3-quietly nil
  "*Set this to non-nil to suppress progress messages while getting mail.")

(defvar epop3-biff-absolutely-silent nil
  "*Set this to non-nil to completely disable biff's progress display.
If this variable is nil, then
If 'epop3-biff-show-progress is nil, only show when biff is snooping.
If 'epop3-biff-show-progress is t, show biff's complete progress.")

(defvar epop3-biff-show-progress nil
  "*Set this to non-nil to show ALL of biff's progress when snooping.
This value is ignored if 'epop3-biff-absolutely-silent' is set to non-nil.")

(defvar epop3-biff-show-barks t
  "*Set this to non-nil for 'biff' to bark on the mode-line for new mail.")

(defvar epop3-biff-show-snooze t
  "*Set this to non-nil for 'biff' to snooze on the mode-line when no mail.")

(defvar epop3-biff-show-numbers nil
  "*Set this to non-nil for 'biff' to display the # of unread messages.")

(defvar epop3-biff-show-mail-string nil
  "*Set this to non-nil for 'biff' to show '[Mail:  ]' in the modeline.
This is only meaningful when `epop3-biff-show-numbers' is non-nil.")

(defvar epop3-biff-show-off-vocabulary t
  "*Set this to non-nil for 'biff' to show off his vocabulary with each biff.
If set to nil, 'biff' will only change barks if the number of pending
messages changes.")

(defvar epop3-biff-show-time t
  "*Set this to non-nil to display the time of last biff in modeline.")

(defvar epop3-biff-ding t
  "*Set this to non-nil to bave Biff 'ding' if there's new mail.")

(defvar epop3-mail-debug nil
  "*Set this to non-nil if debugging `epop3-mail'.")

(defvar epop3-biff-debug nil
  "*Set this to non-nil if debugging the biff features of `epop3-mail'.")

(defvar epop3-biff-differential-mode nil
  "*Set this to non-nil to force biff counting to be differential.

This will speed up biffing when `epop3-leave-mail-on-server' is t,
because the POP3 STAT command is used (quick) instead of the POP3 UIDL
command (possibly expensive).  The downside to setting this to t, is
that Biff cannot bark the *first* time it biffs when
`epop3-leave-mail-on-server' is t.

Biff counting will ordinarily try to use the unread message count,
but if UIDL is found to be unsupported, then biff can only determine
new messages by taking the difference between two successive *total*
message counts, and this variable will be set to t internally.

This value is IGNORED if `epop3-leave-mail-on-server' is nil; otherwise,
this value is set in `epop3-set-biff-differential-mode' if UIDL support
is not found.")

(defvar epop3-biff-idle-grace-seconds 5
  "*Number of seconds Emacs must be idle before a scheduled biff happens.")

(defvar epop3-biff-linear-bark-mode nil
  "*Set this to non-nil to have Biff bark 'number of message' times.
If set to non-nil, this variable overrides `epop3-biff-show-numbers',
and enables a special horizontal-scroll hack for the mode-line.

Not yet implemented ;-).")

(defvar epop3-biff-hook nil
  "List of functions to call after biffing.
Each function is called with two arguments: the current and previous
number of available messages.  For example, to ring the bell once for
each new message detected, use something like this:

    (add-hook 'epop3-biff-hook
          (function (lambda (n old-n)
              (while (> n old-n)
                (beep)
                (sit-for 0.2)
                (setq n (1- n))))))")


;;; }}} {{{ internal variables

;;
;; 'UID' stands for Unique ID
;; 'UIDL' stands for Unique ID List
;;
(defstruct epop3-uid-entry
  (uid nil :read-only t)
  (msgno nil)
  (gotten nil))

(defstruct epop3-msgno-entry
  (msgno nil :read-only t)
  (uid nil :read-only t))

(defstruct epop3-password-entry
  (user@host nil :read-only t)
  (password nil)
  (authentication nil))

(defconst epop3-initial-count -1
  "Value for last-count at initialization.")

(defconst epop3-biff-snooze-string " Zzzz... "
  "Value for biff's snoozing on mode-line if `epop3-biff-show-snooze'.")

(defstruct epop3-host-entry
  (user@host nil :read-only t)
  ;; uidl-support's values: dontknow, yes, no
  (uidl-support 'dontknow)
  (last-count epop3-initial-count))

(defvar epop3-utab nil
  "Uidl hash table for epop3mail.")
(defvar epop3-mtab nil
  "Msgno hash table for epop3mail.")
(defvar epop3-ptab (make-hash-table :test 'equal)
  "Password hash table for epop3mail.")
(defvar epop3-htab (make-hash-table :test 'equal)
  "Host table for epop3mail.")
(defvar epop3-biff-timer nil
  "Timer for biffing.")
(defvar epop3-biff-idle-timer nil
  "Idle timer for biffing.")
(defvar epop3-biff-interval 5
  "Interval in minutes between biffs.")
(defvar epop3-last-biff-at ""
  "Text string describing time of last biff (for debugging).")
(defvar epop3-mode-line-info ""
  "Mode line display string for `epop3-biff'.")
(defvar epop3-biffed-at-least-once nil
  "Non-nil if biffing has been requested at least once.")
(defvar epop3-biffing nil
  "Non-nil if biffing is enabled.")
(defvar epop3-current-bark nil
  "Biff's current bark, if any.")
(defvar epop3-old-n 0
  "Number of available messages at last check.")
(defvar epop3-unix-mail-delimiter ;; jvinson
  (if (eq epop3-mail-package 'gnus)
      message-unix-mail-delimiter
    rmail-unix-mail-delimiter)
  "The regexp string used to delimit messages in UNIX mail format.")

(defconst epop3-mail-version "0.9.5" "Version of epop3mail.")

;;; }}} {{{ the main read mail function

(defun epop3-mail (po:user@host tofile)
  "Get mail from pop server for PO:USER@HOST and put it in TOFILE."
  (when epop3-mail-debug
    (message "starting epop3-mail...")
    (sit-for 1))

  (let ((tmpbuf (get-buffer-create " *pop3-retr*"))
        (biffing epop3-biffing)
        (msgnums nil)
        process)

    (multiple-value-bind (user host) (epop3-parse-po:user@host po:user@host)
      (setq process (epop3-open-server host pop3-port t))
      (when biffing
        (epop3-stop-biff))

      (unwind-protect
          (save-excursion
            (when epop3-mail-debug
              (switch-to-buffer (process-buffer process)))
            (epop3-login process user host epop3-quietly)
            (setq msgnums
                  (epop3-get-message-numbers process user host epop3-quietly))

            (when msgnums
              (let ((msgsleft (1- (length msgnums))))
                (mapc
;;; {{{ the main message retrieval lambda
                 (lambda (msgno)
                   (message
                    (format "retrieving # %d; %d remaining" msgno msgsleft))
                   (pop3-retr process msgno tmpbuf)
                   (epop3-append-message-to-file tmpbuf tofile host)
                   (when (and epop3-leave-mail-on-server
                              (eq 'yes (epop3-uidl-support user host)))
                     (epop3-update-uid-as-gotten msgno))
                   (epop3-clear-buffer tmpbuf)
                   (unless epop3-leave-mail-on-server
                     (pop3-dele process msgno))
                   (decf msgsleft))
;;; }}}
                 msgnums))

              (when epop3-leave-mail-on-server
                (when (eq 'yes (epop3-uidl-support user host))
                  (epop3-save-uidls))
                (when (and biffing epop3-biff-differential-mode)
                  (epop3-update-message-count user host
                                              (epop3-get-stat process t))))))

        (save-excursion
          (let ((proc-buffer (process-buffer process)))
            (pop3-quit process)
            (unless epop3-mail-debug
              (kill-buffer tmpbuf)
              (kill-buffer proc-buffer))
            (when biffing
              (epop3-start-biff epop3-biff-interval))))))))

(defun epop3-flush-password-cache ()
  "Discard all cached pop passwords.
This is a security feature for when you step away from your emacs session
and somebody comes by and evaluates

    (describe-variable (quote epop3-ptab))"
  (interactive)
  (stop-biff)                               ; if biff is running, stop it.
  (clrhash epop3-ptab))
(defalias 'flush-pop-passwords 'epop3-flush-password-cache)

;;; }}} {{{ biff support

(defun* epop3-start-biff (minutes &optional now)
  "Initiate biffing every MINUTES minutes, optionally start biffing NOW."
  (interactive "NHow many minutes between biff checks? ")

  (unless (or epop3-biff-show-barks epop3-biff-show-numbers)
    (message "uh.. check your configuration, biff can't display anything.")
    (return-from epop3-start-biff))

  ;; ---------------- clear out current biff parameters ---------------
  (and epop3-biff-timer (cancel-timer epop3-biff-timer))
  (and epop3-biff-idle-timer (cancel-timer epop3-biff-idle-timer))
  (when (memq 'epop3-mode-line-info global-mode-string)
    (remove-hook 'global-mode-string 'epop3-mode-line-info)
;;; the next line of code seems to cause people mode-line problems...
;;; (remove-hook 'global-mode-string "")
    )

  (setq epop3-biff-timer nil
        epop3-biff-idle-timer nil
        epop3-biffing nil
        epop3-biffed-at-least-once t
        epop3-old-n 0)
  (epop3-format-mode-line nil)

  ;; ---------------------- now start fresh -------------------------
  (cond ((not (eq epop3-password-style 'cache))
         (message "can't biff unless epop3-password-style is 'cache"))
        ((and (< 0 minutes) (< 0 (length epop3-mailbox-list)))
         (when (and (interactive-p) (null now))
           (setq now (y-or-n-p "Do a biff immediately too? "))
           (message ""))
         (unless (memq 'epop3-mode-line-info global-mode-string)
           (add-hook 'global-mode-string "" t nil);; 980121 fix for console
           (add-hook 'global-mode-string 'epop3-mode-line-info t nil))
         (setq epop3-biffing t
               epop3-biff-interval minutes)
         (epop3-format-mode-line 0)
         (if now
             (epop3-biff-all-mailboxes)
           (setq epop3-biff-timer (run-at-time (* 60 minutes)
                                               nil ; no repeat
                                               'epop3-idle-timed-biff))))))

(defalias 'start-biff 'epop3-start-biff)

(defun epop3-stop-biff ()
  "Stop the background biffing cycle."
  (interactive)
  (maphash (lambda (key h-entry)
             (setf (epop3-host-entry-last-count h-entry) epop3-initial-count))
           epop3-htab)
  (epop3-start-biff -1))
(defalias 'stop-biff 'epop3-stop-biff)

(defun epop3-restart-biff ()
  "Restart the background biffing cycle."
  (interactive)
  (epop3-stop-biff)
  (call-interactively 'epop3-start-biff))
(defalias 'restart-biff 'epop3-restart-biff)

(defun epop3-idle-timed-biff ()
  (setq quit-flag nil) ;; recommended by `inhibit-quit's documentation
  (let ((inhibit-quit nil))
    (and epop3-biff-idle-timer (cancel-timer epop3-biff-idle-timer))
    (if (not (sit-for epop3-biff-idle-grace-seconds 0 t))
        (setq epop3-biff-idle-timer
              (run-with-idle-timer epop3-biff-idle-grace-seconds
                                   nil      ; no repeat
                                   'epop3-biff-all-mailboxes))
      (epop3-biff-all-mailboxes))))

(defun epop3-biff-all-mailboxes ()
  "Loop through all pop3 mailboxes and biff each one."
  (interactive)
  (let ((got-one nil)
        (total-unread 0))
    (mapc (lambda (mbox)
            (when (and (string-match "^po:" (file-name-nondirectory mbox))
                       (string-match "@" mbox))
              (setq got-one t)
              (setq total-unread (epop3-biff mbox total-unread))))
          epop3-mailbox-list)
    ;;
    ;; if we don't find a biff-able mailbox, stop biffing!
    ;;
    (if (not got-one)
        (epop3-stop-biff)
      (setq epop3-biff-timer (run-at-time (* 60 epop3-biff-interval)
                                          nil ; no repeat
                                          'epop3-idle-timed-biff)))))

(defun epop3-biff (po:user@host accum-unread)
  "Check mail status for PO:USER@HOST.
This is very much like the mail retrieval except we don't get the mail.
Returns the accumulated number of unread messages waiting ACCUM-UNREAD (if
any) from this round of polling.

If `epop3-leave-mail-on-server' is t and UIDL is supported by all of the
pop3 servers in `rmail-primary-inbox-list', this can be an expensive
operation, since the UIDL command is used instead of the STAT command.
See `epop3-poll-unread' for where the expense comes from."

  (unless epop3-biff-absolutely-silent
    (message (format "biffing %s..." po:user@host)))

  (let ((tmpbuf (get-buffer-create " *pop3-biff*"))
        (msgcount -1)
        (process nil)
        (hush! (if epop3-biff-absolutely-silent
                   t
                 (not epop3-biff-show-progress))))

    (multiple-value-bind (user host) (epop3-parse-po:user@host po:user@host)
      (setq process (epop3-open-server host pop3-port))
      (unwind-protect
          (save-excursion
            (when epop3-biff-debug
              (switch-to-buffer (process-buffer process)))
            (epop3-login process user host hush!)
            (setq msgcount (epop3-poll-unread process user host hush!))
            (epop3-bark-if-necessary user host msgcount accum-unread))

        (save-excursion
          (let ((proc-buffer (process-buffer process)))
            (pop3-quit process)
            (unless epop3-biff-debug
              (kill-buffer tmpbuf)
              (kill-buffer proc-buffer))
            (+ accum-unread msgcount))
          (setq epop3-last-biff-at (current-time-string))
          (unless epop3-biff-absolutely-silent
            (message
             (if epop3-biff-show-time
                 (format "biffing %s...done at %s."
                         po:user@host
                         (format-time-string "%R"  (current-time)))
               (format "biffing %s...done." po:user@host)))))))))

(defun epop3-bark-if-necessary (user host n total)
  "Bark if there are new messages detected for USER @ HOST.
N is the number of unread messages for this mailbox.
TOTAL is the accumulated number of unread messages in other mailboxes."
  (cond (epop3-biff-differential-mode
         ;; we have to do some fancier stuff if we're in difference-mode
         (epop3-differential-mode-bark-if-necessary user host n total))
        (t
         ;; otherwise we assume that 'n' is the number of unread messages
         (epop3-format-mode-line (+ n total)))))

(defun epop3-differential-mode-bark-if-necessary (user host n total)
  "Bark if there are new messages detected for USER @ HOST.
N is the number of unread messages for this mailbox.
TOTAL is the accumulated number of unread messages in other mailboxes.

Differential mode means that biff must check the count of the last
biff for this mailbox and see if there's a difference.  If so,
biff will bark."
  (let* ((user@host (concat user "@" host))
         (last-count (epop3-host-entry-last-count
                      (gethash user@host epop3-htab))))

    (cond ((= last-count epop3-initial-count)
           ;; for the first time, set the baseline count
           (setf (epop3-host-entry-last-count
                  (gethash user@host epop3-htab)) n))
          ((/= last-count n)
           ;; else bark if there's a difference in counts
           (epop3-format-mode-line (+ n total)))
          (t
           (epop3-format-mode-line 0)))))

(defun epop3-set-biff-differential-mode ()
  "Puts biffing into differential mode when UIDL is unsupported.
This may happen if `epop3-leave-mail-on-server' is t and one of the
POP3 servers in `rmail-primary-inbox-list' doesn't support the UIDL command."
  (when (and epop3-biffing (not epop3-biff-differential-mode))
    (epop3-stop-biff)
    (message "epop3-biff: UIDL unsupported -- restarting biff...")
    (sit-for 1)
    (epop3-start-biff epop3-biff-interval t))
  (setq epop3-biff-differential-mode t))

(defun epop3-spaces-around (str)
  "Put spaces around STR."
  (concat " " str " "))

(defun epop3-describe-current-bark ()
  "Describe the language(s) that biff is currently speaking in the mode-line."
  (interactive)
  (cond ((not epop3-biff-show-barks)
         (message "You didn't allow Biff to bark..."))
        ((null epop3-current-bark)
         (message "Biff is not speaking in the mode-line at the moment."))
        ((string= epop3-current-bark epop3-biff-snooze-string)
         (message "Biff is taking nap now."))
        (t
         (or (featurep 'biff-mode) (require 'biff-mode))
         (message (mapconcat 'identity
                             (biff-get-languages-for epop3-current-bark)
                             ", ")))))
(defalias 'biffs-current-language 'epop3-describe-current-bark)

(defun epop3-last-biff-was-at ()
  (interactive)
  (message (concat "biff last checked for mail at " epop3-last-biff-at)))

(defalias 'biffs-last-check 'epop3-last-biff-was-at)

(defun epop3-biff-snooze-string ()
  (if epop3-biff-show-snooze epop3-biff-snooze-string ""))

(defun epop3-biff-mail-string ()
  (if epop3-biff-show-mail-string "Mail: " ""))

(defun epop3-format-mode-line (&optional n)
  "Set the mode-line string for biff.
Parameter N is the number to display if `epop3-biff-show-numbers' is enabled.
If N is nil, clear the mode line."
  (when n
    (run-hook-with-args 'epop3-biff-hook n epop3-old-n))
  (cond ((null n)
         (setq epop3-mode-line-info ""
               epop3-current-bark (epop3-biff-snooze-string)))
        ((zerop n)
         (setq epop3-mode-line-info (epop3-biff-snooze-string)
               epop3-current-bark (epop3-biff-snooze-string)))
        (t
         (when epop3-biff-show-barks
           (or (featurep 'biff-mode) (require 'biff-mode))
           (setq epop3-current-bark (biff-get-bark)))
         (when epop3-biff-ding
           (ding))
         (setq epop3-mode-line-info
               (cond ((and epop3-biff-show-numbers epop3-biff-show-barks)
                      (epop3-spaces-around
                       (format "[%s%d] %s"
                               (epop3-biff-mail-string)
                               n
                               epop3-current-bark)))
                     (epop3-biff-show-numbers
                      (setq epop3-current-bark nil)
                      (epop3-spaces-around (format "[%s%d]"
                                                   (epop3-biff-mail-string)
                                                   n)))
                     (epop3-biff-show-barks
                      (epop3-spaces-around epop3-current-bark))
                     (t
                      "")))
         (setq epop3-old-n (or n 0)))))

(defun epop3-update-message-count (user host n)
  "Set `last-count' for this USER and HOST to N after a mail retrieval.
We do this when biff is in differential-mode."
  (when (and epop3-biff-differential-mode epop3-leave-mail-on-server)
    (let ((user@host (concat user "@" host)))
      (setf (epop3-host-entry-last-count (gethash user@host epop3-htab)) n))))

;;; }}} {{{ uidl support functions

(defconst epop3-uidl-file-name "~/.uidls")
(defconst epop3-current-uidl-file nil)

(defun epop3-get-message-numbers (process user host &optional quietly)
  "Get the list of message numbers to retrieve via PROCESS for USER @ HOST.
Optionally do so QUIETLY."
  ;;
  ;; if we're leaving mail on the server, see if the UIDL command is
  ;; implemented. if so, we use it to get the message number list.
  ;;
  ;; if 'quietly', don't output progress messages.
  ;;
  ;; if we find that UIDL is unsupported (or if we are deleting mail
  ;; after retrieval) then we just use the LIST command.
  ;;
  (or (cond
       (epop3-leave-mail-on-server
        (case (epop3-uidl-support user host)
          ((yes dontknow) (epop3-get-uidl process user host quietly))
          (otherwise (epop3-get-list process quietly))))
       (t
        (epop3-get-list process quietly)))

      ;; fallback for the dontknow and failed case
      (and epop3-leave-mail-on-server
           (eq 'no (epop3-uidl-support user host))
           (epop3-get-list process quietly))))

(defun epop3-uidl-support (user host)
  "Return the status of UIDL command supported for this USER HOST pair.
Return 'yes, 'dontknow, or 'no."
  (epop3-host-entry-uidl-support
   (gethash (concat user "@" host) epop3-htab)))

(defun epop3-get-uidl (process user host &optional quietly)
  "Use PROCESS to get a list of unread message numbers for USER and HOST.
Do this by issuing a POP3 UIDL command, QUIETLY if necessary.
Also remember if UIDL is supported for this USER/HOST combination."
  (unless quietly (message "uidl..."))
  (let ((pairs (pop3-uidl process))
        (hashkey (concat user "@" host)))
    (cond (pairs
           (epop3-init-tables (concat user "." host))
           (mapcar 'epop3-update-tables (cdr pairs))
           (setf (epop3-host-entry-uidl-support
                  (gethash hashkey epop3-htab)) 'yes)
           (epop3-get-unread-message-numbers))
          (t
           (setf (epop3-host-entry-uidl-support
                  (gethash hashkey epop3-htab)) 'no)
           (epop3-set-biff-differential-mode)
           nil))))

(defun epop3-get-list (process &optional quietly)
  "Issue a POP3 LIST command to PROCESS and return a list of message numbers.
Do so QUIETLY if asked to."
  (unless quietly (message "list..."))
  (mapcar (lambda (pair) (car pair))
          (cdr (pop3-list process))))

(defun epop3-poll-unread (process user host &optional quietly)
  "Via PROCESS, determine the number of unread messages for USER/HOST.
Do so QUIETLY if asked to"
  (cond ((and epop3-leave-mail-on-server
              (not epop3-biff-differential-mode))
         ;; the UIDL command can get expensive here for just determining
         ;; the number of unread messages...
         (length (epop3-get-message-numbers process user host quietly)))
        (t
         ;; getting the number of unread messages for
         ;; epop3-biff-differential-mode or for delete-mail-after-retrieve
         ;; is much quicker
         (epop3-get-stat process quietly))))

(defun epop3-get-stat (process &optional quietly)
  "Issue a POP3 STAT command to PROCESS and return its value.
Do so QUIETLY if asked to."
  (unless quietly (message "stat..."))
  (car (pop3-stat process)))

(defun epop3-init-tables (fname)
  "Create the hash tables for uidl processing from data in FNAME.
This is only sensible to do when 'epop3-leave-mail-on-server' is non-nil."
  (save-excursion
    (let ((uid nil)
          (inbuf (generate-new-buffer "*uidls-in*")))
      (set-buffer (get-buffer inbuf))
      (setq epop3-current-uidl-file
            (concat epop3-uidl-file-name "." fname))
      (when (file-readable-p epop3-current-uidl-file)
        (insert-file-contents epop3-current-uidl-file))
      (setq epop3-utab (make-hash-table :test 'equal)
            epop3-mtab (make-hash-table :test 'equal))
      (goto-char (point-min))
      (while (looking-at "\\([^ \n\t]+\\)")
        (setq uid (buffer-substring (match-beginning 1) (match-end 1)))
        (puthash uid (make-epop3-uid-entry :uid uid) epop3-utab)
        (forward-line 1))
      (kill-buffer inbuf))))

(defun epop3-get-unread-message-numbers ()
  "Return a sorted list of unread msg numbers to retrieve."
  (let ((epop3-tmplist '())
        (msgno nil)
        (gotten nil))
    (epop3-dohash (uid u-entry epop3-utab (sort epop3-tmplist '<))
      (setq msgno (epop3-uid-entry-msgno u-entry)
            gotten (epop3-uid-entry-gotten u-entry))
      (when (and msgno (not gotten))
        (push msgno epop3-tmplist)))))

(defun epop3-update-tables (pair)
  "Update uidl-hash tables given a PAIR list (msgno uid)."
  (let ((msgno (car pair))
        (uid (cadr pair))
        (existing-entry (gethash (cadr pair) epop3-utab)))
    (puthash msgno (make-epop3-msgno-entry :uid uid :msgno msgno) epop3-mtab)
    (if (null existing-entry)
        (puthash uid (make-epop3-uid-entry :uid uid :msgno msgno) epop3-utab)
      (setf (epop3-uid-entry-msgno existing-entry) msgno)
      (setf (epop3-uid-entry-gotten existing-entry) t))))

(defun epop3-save-uidls ()
  "Save the updated UIDLs to disk for use next time."
  ;;
  ;; write the uidl, msgid to the local uidl file EXCEPT the ones which
  ;; don't have msgnos, since they've been deleted from the server
  ;;

  (when (and epop3-leave-mail-on-server
             epop3-utab
             (hash-table-count epop3-utab))
    (save-excursion
      (let ((outbuf (generate-new-buffer "*uidls-out*")))
        ;; back this up because we'll write to it later.
        (when (file-readable-p epop3-current-uidl-file)
          (copy-file epop3-current-uidl-file
                     (concat epop3-current-uidl-file ".old")
                     t t))
        (set-buffer outbuf)
        (erase-buffer)
        (maphash 'epop3-insert-uid epop3-utab)
        (write-file epop3-current-uidl-file)
        (kill-buffer outbuf)))))

(defun epop3-update-uid-as-gotten (msgno)
  "Update the uid hash table for MSGNO as 'gotten'."
  (let ((this-uid (epop3-msgno-entry-uid (gethash msgno epop3-mtab))))
    (setf (epop3-uid-entry-gotten (gethash this-uid epop3-utab)) t)))

(defun epop3-insert-uid (uid u-entry)
  "Insert a valid UID from the hash table at point.
U-ENTRY should correspond to UID.  Only UIDLs corresponding to
messages we`ve actually seen or retrieved are inserted."
  (let ((msgno (epop3-uid-entry-msgno u-entry))
        (gotten (epop3-uid-entry-gotten u-entry)))
    (when (and msgno gotten)
      (insert (format "%s\n" uid)))))

;;; }}} {{{ other support functions

(defun epop3-parse-po:user@host (po:user@host)
  "Dissect PO:USER@HOST into USER and HOST strings."
  (let (user host)
    (unless (string-match "^po:\\([^@]*\\)@\\([^:].*\\)$" po:user@host)
      (throw 'exit nil))

    (setq user (substring po:user@host (match-beginning 1) (match-end 1))
          host (substring po:user@host (match-beginning 2) (match-end 2)))
    (values user host)))

(defun epop3-open-server (host port &optional verbose)
  (when verbose
    (message (format "opening connection to %s..." host)))
  (with-timeout (epop3-open-server-timeout
                 (error (format "timeout on opening %s..." host)))
    (pop3-open-server host pop3-port)))


(defun epop3-login (process user host &optional quietly)
  "Perform a pop3 login using PROCESS for USER@HOST.
Do so QUIETLY if asked to."
  (let ((user@host (concat user "@" host)))
    (epop3-set-authentication-scheme user@host)
    (epop3-set-password user@host)

    (case pop3-authentication-scheme
      (apop (unless quietly (message "apop..."))
            (pop3-apop process user))
      (pass (unless quietly (message "user..."))
            (pop3-user process user)
            (unless quietly (message "pass..."))
            (pop3-pass process))
      (otherwise (error "Invalid POP3 authentication scheme.")))))

(defun epop3-set-authentication-scheme (user@host)
  "Determine the pop3 authentication scheme for USER@HOST.
If we are caching passwords, get it from the hash table, otherwise prompt."
  (setq pop3-authentication-scheme
        (case epop3-password-style
          (cache (epop3-get-cached-authentication-scheme user@host))
          (otherwise (epop3-prompt-authentication-scheme user@host)))))

(defun epop3-get-cached-authentication-scheme (user@host)
  "Get the pop3 authentication scheme from the hash table for USER@HOST.
If not there, prompt for it, save it, then return it."
  (let ((key user@host)
        (existing-entry (gethash user@host epop3-ptab)))
    (cond ((null existing-entry)
           (puthash key (make-epop3-password-entry :user@host key) epop3-ptab)
           (puthash key (make-epop3-host-entry :user@host key) epop3-htab)
           (prog1
               ;; prog1 is ugly but whatcha gonna do? gotta do it...
               (setf (epop3-password-entry-authentication
                      (gethash key epop3-ptab))
                     ;; 0.9.4
                     (if epop3-authentication-always-use-default
                         epop3-authentication-default
                       (epop3-prompt-authentication-scheme key)))
             (setf (epop3-password-entry-password (gethash key epop3-ptab))
                   (epop3-prompt-password key))))
          (t
           (epop3-password-entry-authentication existing-entry)))))

(defun epop3-prompt-authentication-scheme (user@host)
  "Interactively get the pop3 authentication scheme for USER@HOST."
  (let ((cursor-in-echo-area t)
        (done nil)
        (res nil)
        (prompt
         (format "authentication for %s? 1 = PASS, 2 = APOP? " user@host)))
    (with-timeout
        (epop3-authentication-timeout-seconds epop3-authentication-default)
      (while (not done)
        (message prompt)
        (case (event-basic-type (read-event))
          (?1 (setq done t res 'pass))
          (?2 (setq done t res 'apop))
          ('return (setq done t res epop3-authentication-default))))
      (discard-input)
      res)))

(defun epop3-set-password (user@host)
  "Determine the pop3 password for USER@HOST, prompting if needed."
  ;; if pop3-password is nil, then the pop3.el library will do the prompting
  (setq pop3-password
        (case epop3-password-style
          (cache (epop3-get-cached-password user@host))
          (otherwise nil))))

(defun epop3-get-cached-password (user@host)
  "Get the pop3 password from cache for USER@HOST.
If not there, prompt for it, save it, then return it."
  (let ((key user@host)
        (existing-entry (gethash user@host epop3-ptab)))
    (cond ((null existing-entry)
           (puthash key (make-epop3-password-entry :user@host key) epop3-ptab)
           (setf (epop3-password-entry-authentication (gethash key epop3-ptab))
                 (epop3-prompt-authentication-scheme key))
           (setf (epop3-password-entry-password (gethash key epop3-ptab))
                 (epop3-prompt-password key)))
          (t
           (epop3-password-entry-password existing-entry)))))

(defun epop3-prompt-password (user@host)
  "Prompt user for USER@HOST's password."
  (discard-input)
  (pop3-read-passwd (format "Password for %s: " user@host)))

(defun epop3-append-message-to-file (frombuf file hostname)
  "Append the incoming message from FROMBUF to FILE.
FILE gets HOSTNAME tacked on to its name."
  (save-excursion
    (set-buffer frombuf)
    ;; some mailers have leading newlines which really screw things up
    ;; later.  nuke 'em.
    (epop3-delete-leading-newlines)
    (epop3-insert-from-heading-if-needed hostname)
    ;; thanks to Jack Vinson <jvinson@chevax.ecs.umass.edu> for
    ;; ensure-final-newline for Gnusen users
    (epop3-ensure-final-newline)
    ;; get rid of that 'wrote file' message in echo area...
    ;; thanks to Sam Rushing <smrushin@cca.rockwell.com> for
    ;; the coding-system-for-write code (for Emacs v 20.2)
    (let ((coding-system-for-write 'undecided-unix))
      (write-region (point-min) (point-max) file t 4 nil))))

;; JMV 1998.08.06
(defun epop3-ensure-final-newline () ;; jvinson
  "Make sure that there is a final newline in the message.
If not, add it.  This is an attempt to fix a problem with Gnus reading mail."
  (save-excursion
    (goto-char (point-max))
    (forward-line -1)
    (unless (looking-at "\n")
      (forward-line 1)
      (insert "\n"))))

(defun epop3-delete-leading-newlines ()
  "Delete all leading empty lines from a buffer."
  (save-excursion
    (goto-char (point-min))
    (while (looking-at "^\n")
      (replace-match "" nil nil))))

(defun epop3-insert-from-heading-if-needed (host)
  "Insert a dummy 'From: HOST' heading if it's needed."
  (save-excursion
    (goto-char (point-min))
    (unless (looking-at epop3-unix-mail-delimiter)
      ;; insert a "From " if necessary.
      (insert (concat "From popmail@" host " " (current-time-string) "\n")))))

(defun epop3-clear-buffer (buffer)
  "Erase the specified BUFFER."
  (save-excursion
    (set-buffer buffer)
    (erase-buffer)))

;;; }}}

;;;--------------------------------------------------------------------------
;; For some people, `pop3-read-process' is broken if an error occurs at
;; the server, so that C-g sometimes doesn't break out.  this replacement
;; is an attempt to alleviate that problem.
;;
;; override pop3.el's version.
;;--------------------------------------------------------------------------
;;; {{{ patched pop3-read-response

(when epop3-override-pop3s-read-response
  (defun pop3-read-response (process &optional return)
    "Read the response from the server.
Return the response string if optional second argument is non-nil."
    (let ((case-fold-search nil)
          match-end)
      (save-excursion
        (set-buffer (process-buffer process))
        (goto-char pop3-read-point)

        ;; if the server is not responding for some reason, we need a way
        ;; to break out of this loop!
        ;; >>>>>>>> begin modifications <<<<<<<<<<<<
        (while (not (search-forward "\r\n" nil t))
          (accept-process-output process 3)
          (goto-char pop3-read-point)
          (when (input-pending-p)
            (pop3-quit process)
            (error "interrupted pop3-read-response!")))
        ;; >>>>>>>> end modifications <<<<<<<<<<<<

        (setq match-end (point))
        (goto-char pop3-read-point)
        (if (looking-at "-ERR")
            (error (buffer-substring (point) (- match-end 2)))
          (if (not (looking-at "+OK"))
              (progn (setq pop3-read-point match-end) nil)
            (setq pop3-read-point match-end)
            (if return
                (buffer-substring (point) match-end)
              t)))))))

;;; }}}

;;---------------------------------------------------------------------------
;; Fix rmail by redefining `rmail-insert-inbox-text'
;; OR: adjust for Gnus usage...
;;--------------------------------------------------------------------------
;;; {{{ patched 'rmail-insert-inbox-text'

(case epop3-mail-package
  (rmail (cond ((= emacs-major-version 20)
                (load "epop3-riit20"))
               (t
                (load "epop3-riit19"))))
  ;; jvinson...
  (gnus (setq nnmail-movemail-program 'epop3-mail
              nnmail-pop-password-required nil)))

;;; }}}

(provide 'epop3mail)

;;; }}}

;;; epop3mail.el ends here
