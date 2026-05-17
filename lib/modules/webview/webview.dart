import 'dart:async';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'dart:typed_data';

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/modules/more/settings/general/providers/general_state_provider.dart';
import 'package:watchtower/services/http/m_client.dart';
import 'package:watchtower/utils/constant.dart';
import 'package:watchtower/utils/global_style.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_svg/flutter_svg.dart';

// ─── AdBlock domain blocklist (EasyList + EasyPrivacy + uBlock Origin – 1561 domains) ──

  const Set<String> _kBlockedDomains = {
    '206ads.com', '24-ads.com', '24x7adservice.com', '33across.com',
  '360ads.com', '3lift.com', '3mads.com', '5advertise.com',
  'a-ads.com', 'a9.com', 'aaxads.com', 'acceptancecrowdadvertising.com',
  'ace-adserver.com', 'ad-adapex.io', 'ad-adblock.com', 'ad-addon.com',
  'ad-arrow.com', 'ad-back.net', 'ad-balancer.net', 'ad-block-offer.com',
  'ad-cheers.com', 'ad-delivery.net', 'ad-fam.com', 'ad-flow.com',
  'ad-free.info', 'ad-m.asia', 'ad-mapps.com', 'ad-maven.com',
  'ad-mixr.com', 'ad-nex.com', 'ad-plus.cn', 'ad-recommend.com',
  'ad-score.com', 'ad-server.co.za', 'ad-serverparc.nl', 'ad-shield.io',
  'ad-srv-track.com', 'ad-srv.net', 'ad-stir.com', 'ad-tech.ru',
  'ad-track.jp', 'ad-vortex.com', 'ad.gt', 'ad.guru',
  'ad.nl', 'ad.page', 'ad.plus', 'ad.style',
  'ad20.net', 'ad2adnetwork.biz', 'ad2bitcoin.com', 'ad2f8c6f8e.com',
  'ad2iction.com', 'ad2the.net', 'ad4.com.cn', 'ad4989.co.kr',
  'ad4game.com', 'ad5track.com', 'ad6media.fr', 'ad7.com',
  'ad7mylo.com', 'ad999.biz', 'ada9d543ce.com', 'adabra.com',
  'adac.de', 'adacado.com', 'adacreisen.de', 'adactioner.com',
  'adactive.cz', 'adacts.com', 'adadvisor.net', 'adagcaladoise.fr',
  'adage.com', 'adagora.com', 'adalh-zcq.com', 'adalliance.io',
  'adalso.com', 'adalyser.com', 'adam.page', 'adamantslash.com',
  'adamantsnail.com', 'adamasconsulting.com', 'adamatic.co', 'adandhub.com',
  'adangle.online', 'adaos-ads.net', 'adap.tv', 'adapd.com',
  'adapex.io', 'adapf.com', 'adappi.co', 'adaptavist.com',
  'adapterwith1024.net', 'adaptive.marketing', 'adaptiveinsights.com', 'adaptiveplanning.com',
  'adaptris.com', 'adaptunemployed.com', 'adaquest.com', 'adara.com',
  'adaround.net', 'adarutoad.com', 'adasgsts.cc', 'adating.link',
  'adatrix.com', 'adbard.net', 'adbasket.net', 'adbdilajvoxw.in',
  'adbeacon.com', 'adbestnet.com', 'adbetclickin.pink', 'adbetnetwork.com',
  'adbility-media.com', 'adbinead.com', 'adbit.biz', 'adbits.online',
  'adblade.com', 'adblck.com', 'adblock-360.com', 'adblock-guru.com',
  'adblock-zen.com', 'adblock.fr', 'adblockanalytics.com', 'adblocker-sentinel.net',
  'adblockermax.com', 'adblockeromega.com', 'adblockersentinel.com', 'adblockfast.com',
  'adblockrelief.com', 'adblockstream.com', 'adblockstrtape.link', 'adblockstrtech.link',
  'adblockultimate.net', 'adbmi.com', 'adboost.it', 'adbooth.com',
  'adbox.lv', 'adbpage.com', 'adbpdtuylbvlk.space', 'adbrite.com',
  'adbro.me', 'adbuddiz.com', 'adbuff.com', 'adbull.com',
  'adbutler-fermion.com', 'adbutler.com', 'adbutter.net', 'adbwublzlyxvg.online',
  'adbyss.com', 'adc-serv.net', 'adca.st', 'adcalls.nl',
  'adcalm.com', 'adcannyxml.com', 'adcash.com', 'adcdnx.com',
  'adcell.com', 'adcell.de', 'adcharriot.com', 'adcleanerpage.com',
  'adclear.net', 'adclerks.com', 'adclick.pk', 'adclickad.com',
  'adclickafrica.com', 'adclickbyte.com', 'adclickmedia.com', 'adclickppc.com',
  'adclicks.io', 'adcloud.net', 'adclr.jp', 'adcolo.com',
  'adcolony.com', 'adconjure.com', 'adconscious.com', 'adcontext.pl',
  'adcontroll.com', 'adcovery.com', 'adcpioqpzvvla.website', 'adcrax.com',
  'adcrowd.com', 'add-solution.de', 'addabilify.com', 'addefenderplus.info',
  'addfreestats.com', 'addictedattention.com', 'addictrelive.com', 'addin1.name',
  'addiply.com', 'additionalmedia.com', 'additionzipper.com', 'additudemag.com',
  'addizhi.top', 'addkt.com', 'addoer.com', 'addonsmash.com',
  'addoor.net', 'addotnet.com', 'addressfriend.com', 'addroid.com',
  'addroplet.com', 'addskills.se', 'addthief.com', 'addthis.com',
  'addthiscdn.com', 'addthisedge.com', 'addwish.com', 'addynamix.com',
  'addynamo.net', 'adebtt.info', 'adecn.com', 'adehhurslxxmh.space',
  'adelaidenow.com.au', 'adelement.com', 'adelixir.com', 'adelphic.com',
  'adelphic.net', 'ademails.com', 'adenc.co.kr', 'adengage.com',
  'adentifi.com', 'adenza.dev', 'adept-peak.pro', 'adept-shock.pro',
  'adept-telecom.co.uk', 'adepticily.com', 'adeptmind.ai', 'aderant.com',
  'adespresso.com', 'adetxlcpwbrjcnr.com', 'adevppl.com', 'adex.media',
  'adexc.net', 'adexchangeclear.com', 'adexchangecloud.com', 'adexchangedirect.com',
  'adexchangegate.com', 'adexchangeguru.com', 'adexchangemachine.com', 'adexchangerapid.com',
  'adexchangetracker.com', 'adexcite.com', 'adexmedias.com', 'adextrem.com',
  'adf.ly', 'adf01.net', 'adfeedstrk.com', 'adfenix.com',
  'adfgetlink.net', 'adfinity.pro', 'adfinix.com', 'adflyer.media',
  'adfoc.us', 'adfootprints.com', 'adforcast.com', 'adforgames.com',
  'adforge.io', 'adform.com', 'adform.net', 'adfox.ru',
  'adfpoint.com', 'adfrika.com', 'adfrontiers.com', 'adfusion.com',
  'adfyre.co', 'adgage.es', 'adgainersolutions.com', 'adgard.net',
  'adgatemedia.com', 'adgcufmqcuedr.online', 'adgear.com', 'adgebra.co.in',
  'adgebra.in', 'adgfnqyujjqcq.online', 'adgitize.com', 'adgjl13.com',
  'adglare.net', 'adglare.org', 'adglidepro.com', 'adgocoo.com',
  'adgoi.com', 'adgonehefeltlone.com', 'adgorithms.com', 'adgreed.com',
  'adgrid.io', 'adgroups.com', 'adgrx.com', 'adguardvpnnew.biz',
  'adhash.com', 'adhaven.com', 'adhdinsight.com', 'adhduniversity.com',
  'adhealers.com', 'adheart.de', 'adhese.be', 'adhese.com',
  'adhese.net', 'adhigh.net', 'adhitzads.com', 'adhoc2.net',
  'adhouse.pro', 'adhslx.com', 'adhub.digital', 'adhub.media',
  'adhunt.net', 'adiamor.com', 'adidas.ae', 'adidas.be',
  'adidas.ca', 'adidas.ch', 'adidas.cn', 'adidas.co',
  'adidas.co.in', 'adidas.co.kr', 'adidas.co.uk', 'adidas.com',
  'adidas.com.ar', 'adidas.com.au', 'adidas.com.br', 'adidas.cz',
  'adidas.de', 'adidas.dk', 'adidas.es', 'adidas.fi',
  'adidas.fr', 'adidas.gr', 'adidas.hu', 'adidas.ie',
  'adidas.it', 'adidas.jp', 'adidas.mx', 'adidas.nl',
  'adidas.no', 'adidas.pl', 'adidas.pt', 'adidas.ru',
  'adidas.se', 'adidas.sk', 'adiglobal.us', 'adikteev.com',
  'adimise.com', 'adimpact.com', 'adinc.co.kr', 'adinc.kr',
  'adinch.com', 'adingo.jp', 'adinplay.com', 'adinsight.co.kr',
  'adinsight.com', 'adinte.jp', 'adintend.com', 'adinterax.com',
  'adinvigorate.com', 'adipolo.com', 'adipolosolutions.com', 'adiquity.com',
  'adireland.com', 'adireto.com', 'adisfy.com', 'adisn.com',
  'adit-media.com', 'adition.com', 'aditize.com', 'aditms.me',
  'aditsafeweb.com', 'aditserve.com', 'aditude.cloud', 'aditude.io',
  'adjal.com', 'adjector.com', 'adjfiramdo.in', 'adjoinartistic.com',
  'adjoininglearning.com', 'adjs.media', 'adjug.com', 'adjuggler.com',
  'adjuggler.net', 'adjungle.com', 'adjust.com', 'adjux.com',
  'adk2x.com', 'adkaora.space', 'adkernel.com', 'adklicyjfcjuo.tech',
  'adklimages.com', 'adklip.com', 'adkmbc.com', 'adknowledge.com',
  'adkonekt.com', 'adkora.com', 'adkova.com', 'adktinpfdhtsw.website',
  'adku.co', 'adku.com', 'adlane.info', 'adlatch.com',
  'adlayer.net', 'adlegend.com', 'adlermode.com', 'adless.io',
  'adligature.com', 'adlightning.com', 'adliners.de', 'adlink.net',
  'adlive.io', 'adlogists.com', 'adlook.me', 'adloop.co',
  'adloox.com', 'adlooxtracking.com', 'adlpartner.com', 'adlperformance.es',
  'adlpo.com', 'adlserq.com', 'adltserv.com', 'adlux.com',
  'admaaodfwkcuj.store', 'admachina.com', 'adman.gr', 'admana.net',
  'admanager.google.com', 'admanmedia.com', 'admantx.com', 'admaru.com',
  'admaster.com.cn', 'admasters.media', 'admatic.de', 'admatrix.jp',
  'admax.network', 'admaxim.com', 'admaxium.com', 'admd.ink',
  'admdoqipetokp.space', 'adme-net.com', 'admedia.com', 'admediaportal.com',
  'admediasales.com', 'admediatex.net', 'admedit.net', 'admedo.com',
  'admeerkat.com', 'admeira.ch', 'admeking.com', 'admeridianads.com',
  'admetric.io', 'admetrics.events', 'admetricspro.com', 'admicro.vn',
  'admidainsight.com', 'admile.ru', 'adminer.com', 'administrarweb.es',
  'admirableinstance.com', 'admiral.pub', 'admiralproxied.com', 'admired-force.pro',
  'admiredjumper.com', 'admiredpopulation.pro', 'admiredshame.com', 'admission.net',
  'admissionaudit.com', 'admissionpersuade.com', 'admitad-connect.com', 'admitad.com',
  'admittedhi.com', 'admixer.md', 'admixer.net', 'admjmp.com',
  'admmontreal.com', 'admo.tv', 'admob-cn.com', 'admob.com',
  'admobe.com', 'admonishfistgipsy.com', 'admonishmenttub.com', 'admost.com',
  'admothreewallent.com', 'admpire.com', 'admszahcketzf.site', 'admtech.com.au',
  'admtoronto.com', 'admulti.com', 'adn.cloud', 'adnade.net',
  'adnami.io', 'adnami2.io', 'adnanny.com', 'adncdn.net',
  'adnet.biz', 'adnet.com', 'adnet.de', 'adnet.lt',
  'adnet.ru', 'adnetwrk.com', 'adnext.co', 'adnext.fr',
  'adnext.pl', 'adngin.com', 'adnico.jp', 'adnigma.com',
  'adnimation.com', 'adnimo.com', 'adnitro.pro', 'adnium.com',
  'adnmore.co.kr', 'adnotbad.com', 'adnotebook.com', 'adnow.com',
  'adnradio.cl', 'adnuntius.com', 'adnxs-simple.com', 'adnxs.com',
  'adnxs.net', 'adnxs1.com', 'ado.hu', 'adobe.com',
  'adobe.io', 'adobe.ly', 'adobe.net', 'adobedemo.com',
  'adobedemosystem.com', 'adobedtm.com', 'adobedxcusteng.com', 'adobemailing.com',
  'adoberesources.net', 'adobesandbox.com', 'adobespark.com', 'adobesystemsinc.com',
  'adobetag.com', 'adobetarget.com', 'adobevlab.com', 'adocean.pl',
  'adoftheyear.com', 'adolcgailvycg.site', 'adolescent-bonus.pro', 'adolescentzone.com',
  'adomic.com', 'adomik.com', 'adonnews.com', 'adonsonlyd.xyz',
  'adonweb.ru', 'adop.cc', 'adop.co', 'adoperator.com',
  'adoperatorx.com', 'adopexchange.com', 'adopsboost.com', 'adopstar.uk',
  'adoptim.com', 'adoptum.net', 'adorableanger.com', 'adorableattention.com',
  'adorablecover.com', 'adorablenet.com', 'adorableold.com', 'adorarama.com',
  'adorebeauty.com.au', 'adoredaffection.com', 'adoreplans.com', 'adoric-om.com',
  'adorika.com', 'adornmadeup.com', 'adornmenttaunt.com', 'adosia.com',
  'adotic.com', 'adotmob.com', 'adoto.net', 'adotone.com',
  'adotube.com', 'adp.ca', 'adp.ch', 'adp.co.uk',
  'adp.com', 'adpacks.com', 'adpahqji.in', 'adparlor.com',
  'adpass.co.uk', 'adpaths.com', 'adpatrof.com', 'adpay.com',
  'adpays.net', 'adpeepshosted.com', 'adperfect.com', 'adperium.com',
  'adpick.co.kr', 'adpicmedia.net', 'adpies.com', 'adpinfo.com',
  'adpinion.com', 'adpionier.de', 'adpkdquestions.com', 'adplay.ru',
  'adplex.co.kr', 'adplogger.no', 'adplsr.com', 'adplugg.com',
  'adplushub.com', 'adplxmd.com', 'adpmbexo.com', 'adpmbexoxvid.com',
  'adpmbglobal.com', 'adpmbtf.com', 'adpmbtj.com', 'adpmbts.com',
  'adpnut.com', 'adpod.in', 'adpon.jp', 'adpone.com',
  'adpool.bet', 'adpopblocker.com', 'adport.io', 'adpredictive.com',
  'adpresenter.de', 'adpri.org', 'adprime.com', 'adpushup.com',
  'adquake.com', 'adquality.ch', 'adquery.io', 'adquire.com',
  'adqva.com', 'adrange.net', 'adrdmshvjobez.space', 'adreactor.com',
  'adreadytractions.com', 'adrealclick.com', 'adrecord.com', 'adrecover.com',
  'adrecreate.com', 'adreform.com', 'adregain.com', 'adregain.ru',
  'adrelayer.com', 'adrenovate.com', 'adrent.net', 'adresellers.com',
  'adrevenuerescue.com', 'adrevolver.com', 'adrgyouguide.com', 'adrianpeachdesign.com',
  'adrifttenderly.com', 'adright.co', 'adrino.io', 'adrise.de',
  'adrise.tv', 'adrizer.com', 'adro.co', 'adro.pro',
  'adrocket.com', 'adroeaxawwukc.website', 'adroitcertain.com', 'adroitham.com',
  'adrokt.com', 'adroll.com', 'adrsbl.io', 'adrscibgiosrk.website',
  'adrta.com', 'adrtx.net', 'adrunnr.com', 'ads-abc.com',
  'ads-adv.top', 'ads-bitcoin.com', 'ads-blocker.app', 'ads-blocker.pro',
  'ads-on-line.com', 'ads-pixiv.net', 'ads-twitter.com', 'ads.cc',
  'ads.linkedin.com', 'ads.yahoo.com', 'ads1-adnow.com', 'ads1-adqva.com',
  'ads2550.bid', 'ads2ads.net', 'ads3-adnow.com', 'ads4g.pl',
  'ads4media.online', 'ads4trk.com', 'ads5-adnow.com', 'ads6-adnow.com',
  'ads7-adnow.com', 'adsafeprotected.com', 'adsafety.net', 'adsame.com',
  'adsappier.com', 'adsarcade.com', 'adsave.co', 'adsb4trk.com',
  'adsbar.online', 'adsbetnet.com', 'adsbookie.com', 'adsboosters.xyz',
  'adsbreak.com', 'adsbtrk.com', 'adsbuddy.net', 'adscale.com',
  'adscale.de', 'adscampaign.net', 'adscdn.net', 'adschill.com',
  'adschoom.com', 'adscienceltd.com', 'adsco.re', 'adscore.com',
  'adscout.io', 'adscreendirect.com', 'adsdatastream.top', 'adsdk.com',
  'adsdot.ph', 'adsenix.com', 'adsensecamp.com', 'adsensecustomsearchads.com',
  'adsensedetective.com', 'adserve.com', 'adserve.ph', 'adserverplus.com',
  'adserverpub.com', 'adservice.google.com', 'adservicemedia.dk', 'adservingfactory.com',
  'adservon.com', 'adservrs.com', 'adsession.com', 'adsessionserv.com',
  'adsethimdown.org', 'adsettings.com', 'adsexse.com', 'adsfac.eu',
  'adsfac.net', 'adsfac.us', 'adsfast.com', 'adsfcdn.com',
  'adsforallmedia.com', 'adsfuse.com', 'adshack.com', 'adshnk.com',
  'adshopping.com', 'adshostnet.com', 'adshot.de', 'adsiduous.com',
  'adsight.nl', 'adsinstant.com', 'adsinteractive.com', 'adsixmedia.fr',
  'adsjqaobchetb.space', 'adskape.ru', 'adskeeper.co.uk', 'adskeeper.com',
  'adskom.com', 'adskpak.com', 'adslidango.com', 'adslivecorp.com',
  'adsloboclick.com', 'adsloom.com', 'adslop.com', 'adslop.link',
  'adslot.com', 'adsmarch.online', 'adsmarket.com', 'adsmart.hk',
  'adsmatcher.com', 'adsmeasurement.com', 'adsmediabox.com', 'adsmediator.com',
  'adsmoloco.com', 'adsnative.com', 'adsninja.ca', 'adsniper.ru',
  'adsoftware.top', 'adsolutely.com', 'adsolutions.com', 'adsonar.com',
  'adsoptimal.com', 'adsparc.net', 'adspdbl.com', 'adspector.io',
  'adspeed.com', 'adspeed.net', 'adspi.xyz', 'adspirit.de',
  'adsplay.in', 'adsplex.com', 'adspop.me', 'adspredictiv.com',
  'adspruce.com', 'adspsp.com', 'adspygl.xyz', 'adspyglass.com',
  'adsquash.info', 'adsquasher.com', 'adsquasher.pro', 'adsquirrel.ai',
  'adsreference.com', 'adsring.com', 'adsrt.com', 'adsrv.net',
  'adsrv.wtf', 'adsrv4k.com', 'adsrvmedia.com', 'adsrvr.org',
  'adss.com', 'adssistem.com', 'adstargeting.com', 'adstargets.com',
  'adstean.com', 'adsterra.com', 'adsterratech.com', 'adstik.click',
  'adstk.io', 'adstock.pro', 'adstoo.com', 'adstook.com',
  'adstoppedtotalkto.com', 'adstreampro.com', 'adstub.net', 'adstudio.cloud',
  'adstuna.com', 'adsturn.com', 'adsummos.net', 'adsupply.com',
  'adsupplyads.com', 'adsupplyads.net', 'adsupplyssl.com', 'adsurve.com',
  'adsvert.com', 'adsvolum.com', 'adsvolume.com', 'adsvzkuzfcfbz.one',
  'adswam.com', 'adswip.com', 'adswizz.com', 'adsxtits.com',
  'adsxtits.pro', 'adsxyz.com', 'adsync.tech', 'adt-worldwide.com',
  'adt.cl', 'adt.co.uk', 'adt.com', 'adt.com.br',
  'adt.com.mx', 'adt328.com', 'adt545.net', 'adt567.net',
  'adt574.com', 'adt598.com', 'adtags.mobi', 'adtaily.com',
  'adtaily.pl', 'adtarget.biz', 'adtarget.market', 'adtarget.me',
  'adtdp.com', 'adtear.com', 'adtech.de', 'adtechium.com',
  'adtechjp.com', 'adtechus.com', 'adtector.com', 'adtegrity.net',
  'adtelligence.de', 'adtelligent.com', 'adten.eu', 'adteractive.com',
  'adthletic.com', 'adthrive.com', 'adtimaserver.vn', 'adtival.com',
  'adtival.network', 'adtive.com', 'adtkhudcu.in', 'adtlgc.com',
  'adtng.com', 'adtoma.com', 'adtonement.com', 'adtonos.com',
  'adtoox.com', 'adtotal.pl', 'adtpix.com', 'adtqjaclmjanq.space',
  'adtr.io', 'adtrace.org', 'adtraction.com', 'adtraxx.de',
  'adtrcdn.io', 'adtrhogpvnwkt.space', 'adtriba.com', 'adtrieval.com',
  'adtrix.com', 'adtrue.com', 'adtrue24.com', 'adtumxjckljej.space',
  'adult-chess.com', 'adult.xyz', 'adult3dcomics.com', 'adultadvertising.net',
  'adultadworld.com', 'adultblogtoplist.com', 'adultcamchatfree.com', 'adultcamfree.com',
  'adultcamliveweb.com', 'adultforce.com', 'adultfriendfinder.com', 'adultgameexchange.com',
  'adultimate.net', 'adultium.com', 'adultlinkexchange.com', 'adultminglenight.click',
  'adultmoviegroup.com', 'adultonlineplay.com', 'adultpics.wiki', 'adultsense.com',
  'adultsense.net', 'adultsense.org', 'adultsjuniorfling.com', 'adultswim.co.uk',
  'adultswim.com', 'adunity.com', 'adup-tech.com', 'adv-adserver.com',
  'advally.com', 'advalo.com', 'advanced-energy.com', 'advancedadblocker.pro',
  'advancedmd.com', 'advancedpowertech.com', 'advancedpractice.com', 'advancedtech.com',
  'advanceflooring.co.nz', 'advancesavings.ca', 'advangelists.com', 'advanseads.com',
  'advant-connection.life', 'advantage.tech', 'advantageman.com', 'advantageroughplay.com',
  'advard.com', 'advcash.com', 'advconversion.com', 'advectas.se',
  'adventkk.co.jp', 'adventori.com', 'adventurefeeds.com', 'adventuretix.com',
  'adventurousamount.com', 'adverdirect.com', 'adverge.ai', 'adversal.com',
  'adversaldisplay.com', 'adversalservers.com', 'adverserve.net', 'advertease.store',
  'advertica.com', 'adverticum.net', 'advertipros.com', 'advertise.com',
  'advertiserurl.com', 'advertiseserve.com', 'advertisespace.com', 'advertising-cdn.com',
  'advertising.com', 'advertising365.com', 'advertisingiq.com', 'advertisingvalue.info',
  'advertisoo.com', 'advertix.space', 'advertizmenttoyou.com', 'advertjunction.com',
  'advertlets.com', 'advertnative.com', 'advertone.ru', 'advertpay.net',
  'advertserve.com', 'advertsource.co.uk', 'advertur.ru', 'advfeeds.com',
  'advgo.net', 'adviad.com', 'advicemedia.com', 'advidates.com',
  'advil.com', 'advisedlycourier.com', 'advisedwhenever.com', 'adviso.ca',
  'advisorsres.com', 'advisorthrowbible.com', 'advisory.com', 'advisorycloud.com',
  'adviva.net', 'advmaker.ru', 'advmd.com', 'advmedialtd.com',
  'advmonie.com', 'advocate420.fun', 'advombat.ru', 'advon.net',
  'advoncommerce.com', 'advotionhot.com', 'advp1.com', 'advp2.com',
  'advp3.com', 'advpx.com', 'advpy.com', 'advpz.com',
  'advservert.com', 'advsnx.net', 'advtise.net', 'adw9.com',
  'adwalte.info', 'adway.org', 'adways.com', 'adweb.co.kr',
  'adwebster.com', 'adweek.com', 'adwerx.com', 'adworldmedia.com',
  'adworldmedia.net', 'adwozwzigog.in', 'adwstats.com', 'adwx6vcj.com',
  'adx-t.com', 'adx.io', 'adx.ws', 'adx1.com',
  'adxadserv.com', 'adxadtracker.com', 'adxapi.online', 'adxawkejwjdfh.site',
  'adxbid.info', 'adxcel-ec2.com', 'adxfire.in', 'adxfire.net',
  'adxhand1.name', 'adxion.com', 'adxnexus.com', 'adxoo.com',
  'adxpansion.com', 'adxpartner.com', 'adxplay.com', 'adxpose.com',
  'adxpremium.com', 'adxpremium.services', 'adxpub.com', 'adxscope.com',
  'adxsource.com', 'adxsrver.com', 'adxtag.online', 'adxvip.com',
  'adxxx.biz', 'adxxxxxmost.co', 'adyapper.com', 'adyhvkirh.com',
  'adyoulike.com', 'adypxnnfptavg.website', 'adysis.com', 'adyxnckaseupgmk.com',
  'adz2you.xyz', 'adzbazar.com', 'adzblockersentinel.net', 'adzcivwjgktmz.site',
  'adzerk.net', 'adziff.com', 'adzilla1.name', 'adzintext.com',
  'adzivijnyizgp.space', 'adzmedia.com', 'adzmob.com', 'adzouk.com',
  'adzpier.com', 'adzs.com', 'adzs.nl', 'adzshield.info',
  'afdads.com', 'affbuzzads.com', 'afterdownloads.com', 'afyads.com',
  'al-adtech.com', 'alleliteads.com', 'alternads.info', 'alturaadvertising.com',
  'amazon-adsystem.com', 'amplitude.com', 'analytics.twitter.com', 'anonymousads.com',
  'aolcloud.net', 'appnexus.com', 'appsflyer.com', 'appsflyersdk.com',
  'aprilads.space', 'aqua-adserver.com', 'aseads.com', 'assoc-amazon.com',
  'autoads.asia', 'avads.co.uk', 'avads.live', 'avads.net',
  'ayads.co', 'azoogleads.com', 'babyboomboomads.com', 'bc.vc',
  'benefit-ads.com', 'bestfunnyads.com', 'betads.xyz', 'betteradsystem.com',
  'bidderads.com', 'bidswitch.net', 'bigboxads.com', 'bitcoinadvertise.net',
  'blamads.com', 'blockchain-ads.com', 'blogads.com', 'blogherads.com',
  'bmfads.com', 'bmmads.com', 'boomads.com', 'boostads.net',
  'bounceads.net', 'brainlyads.com', 'branch.io', 'brandads.net',
  'broadstreetads.com', 'brodownloads.site', 'buysellads.com', 'buysellads.net',
  'carbonads.com', 'casalemedia.com', 'cash-ads.com', 'cdn-adtech.com',
  'cdn4ads.com', 'cdnads.com', 'cdnthreads.com', 'celeb-ads.com',
  'chainads.io', 'city-ads.de', 'cleanmediaads.com', 'cleverads.vn',
  'clickadu.com', 'clickadu.net', 'clickmintads.site', 'clivads.com',
  'clkmon.com', 'clkrev.com', 'cmadserver.de', 'cmfads.com',
  'coin-hive.com', 'coinads.online', 'coinhive.com', 'connectingthreads.com',
  'content.ad', 'contextads.live', 'contextuads.com', 'conversantmedia.com',
  'cookielaw.org', 'cookpad-ads.com', 'coolerads.com', 'counciladvertising.net',
  'cpmstar.com', 'cpvadvertise.com', 'crazyegg.com', 'crispads.com',
  'criteo.com', 'criteo.net', 'crypto-ads.net', 'cryptoloot.pro',
  'cuisineenvoyadvertise.com', 'customads.co', 'da-ads.com', 'datedeskads.com',
  'datingsspads.com', 'deployads.com', 'didomi.io', 'digitaladvertisingalliance.org',
  'directadvert.ru', 'disneyadvertising.com', 'disqusads.com', 'districtm.io',
  'domainadvertising.com', 'dopaleads.com', 'doubleadserve.com', 'doubleclick-cn.net',
  'doubleclick.com', 'doubleclick.net', 'doublepimpads.com', 'dribbleads.com',
  'dsu-adguard.pro', 'e-ads.com', 'eads.com', 'easy-ads.com',
  'eazyleads.com', 'ebayadservices.com', 'eficads.com', 'egadvertising.com',
  'elephant-ads.com', 'emxdgt.com', 'epicgameads.com', 'eqads.com',
  'ero-advertising.com', 'eroadvertising.com', 'essayads.com', 'ethereumads.com',
  'ethicalads.io', 'euro4ads.de', 'euroads.dk', 'exoclick.com',
  'exoticads.com', 'explorads.com', 'eyeviewads.com', 'fc.lc',
  'feed-ads.com', 'fireworkadservices.com', 'fireworkadservices1.com', 'flagads.net',
  'flashtalking.com', 'flat-ads.com', 'flower-ads.com', 'fluxads.com',
  'flyingadvert.com', 'flymyads.com', 'fmsads.com', 'fortuneadvert.com',
  'fpadserver.com', 'freakads.com', 'freefromads.com', 'freefromads.pro',
  'freewheel.com', 'freewheel.tv', 'frivol-ads.com', 'fullstory.com',
  'fundingchoicesmessages.google.com', 'fusionads.net', 'futureads.io', 'gameads.io',
  'gatorleads.co.uk', 'gbads.net', 'geelongadvertiser.com.au', 'gentwoleads.top',
  'getflowads.net', 'getgoogletagmanager.com', 'getmyads.com', 'gitads.dev',
  'glsfreeads.com', 'gmads.net', 'gmmads.com', 'goads.pro',
  'goadserver.com', 'goadservices.com', 'goodadvert.ru', 'googleadservices-cn.com',
  'googleadservices.com', 'googlesyndication.com', 'googletagmanager.com', 'googletagservices.com',
  'gourmetads.com', 'gpsecureads.com', 'greenads.org', 'groovinads.com',
  'happierleads.com', 'highspeedads.top', 'hilltopads.com', 'hilltopads.net',
  'himediads.com', 'hipersushiads.com', 'hotjar.com', 'hubdigitalads.com',
  'hueads.com', 'huluads.info', 'hunt-leads.com', 'iionads.com',
  'imyanmarads.com', 'in-appadvertising.com', 'indexexchange.com', 'indoleads.com',
  'indyadvertising.com', 'inexpedientlads.com', 'infinite-ads.com', 'infinityads.com',
  'influads.com', 'innovateads.com', 'innovid.com', 'insurads.com',
  'interactiveads.ai', 'intersads.com', 'inviziads.com', 'ioadserve.com',
  'jads.cc', 'jads.co', 'jsecoin.com', 'jubnaadserve.com',
  'juicyads.com', 'juicyads.me', 'kinkadservercdn.com', 'kiosked.com',
  'kmspicodownloads.com', 'kochava.com', 'kunvertads.com', 'kvhfewmbwyads.online',
  'kyoads.com', 'leadadvert.info', 'leads.direct', 'lijit.com',
  'likeads.com', 'list-ads.com', 'lkqd.net', 'logrocket.com',
  'luckyads.pro', 'madserving.com', 'magicads.nl', 'makenoads.com',
  'mangoads.net', 'manureads.com', 'mariads.cfd', 'marsads.com',
  'mathads.com', 'mathilde-ads.com', 'mayads.store', 'mbsspads.com',
  'media.net', 'medleyads.com', 'medyanetads.com', 'meowadvertising.com',
  'mgid.com', 'minutemedia-prebid.com', 'mixadvert.com', 'mixpanel.com',
  'mk-ads.com', 'mlnadvertising.com', 'mnetads.com', 'mng-ads.com',
  'moatads.com', 'moatpixel.com', 'monetixads.com', 'montgomeryadvertiser.com',
  'moonads.net', 'morningadvertiser.co.uk', 'mouseflow.com', 'msads.net',
  'multiwall-ads.shop', 'myaudioads.com', 'mypopads.com', 'myprecisionads.com',
  'nads.io', 'nameads.com', 'native-adserver.com', 'nativeads.com',
  'ncadvertiser.com', 'neads.delivery', 'nellads.com', 'netsolads.com',
  'newjulads.com', 'newmayads.com', 'newoctads.com', 'newsatads.com',
  'newsunads.com', 'newthuads.com', 'newtueads.com', 'ngadverts.com',
  'nielsen.com', 'nikkiexxxads.com', 'norfolkbroads.com', 'northrtbads.top',
  'nr-data.net', 'nzme-ads.co.nz', 'oboxads.com', 'octoberads.space',
  'omni-ads.com', 'onclickads.net', 'onetrust.com', 'openadserving.com',
  'openx.com', 'openx.net', 'optiads.org', 'optoutadvertising.com',
  'orangeads.fr', 'ouo.io', 'ourtecads.com', 'outbrain.com',
  'outleads.com', 'pagead2.googlesyndication.com', 'pangle-ads.com', 'papayads.net',
  'partner-ads.com', 'pc-ads.com', 'pityneedsdads.com', 'pladform.ru',
  'plugrush.com', 'polymorphicads.jp', 'popads.media', 'popads.net',
  'popmyads.com', 'popsads.net', 'porchadvertise.com', 'powferads.com',
  'prebid.io', 'prebid.org', 'predictivadvertising.com', 'premiumads.com.br',
  'premiumads.net', 'primaryads.com', 'pro-advert.de', 'propellerads.com',
  'propellerads.tech', 'prplads.com', 'publisherads.click', 'pubmatic.com',
  'pulpyads.com', 'purpleads.io', 'pushadvert.bid', 'quantcast.com',
  'quantserve.com', 'quantumads.com', 'quickads.net', 'rakutenadvertising.io',
  're-ads.com', 'readserv.com', 'redads.com', 'rediads.com',
  'redirect-ads.com', 'refinedads.com', 'regionads.ru', 'retailads.net',
  'revcontent.com', 'revive-adserver.net', 'revupads.com', 'rexadvert.xyz',
  'rhombusads.com', 'rhythmone.com', 'richads.com', 'robesadvertisement.com',
  'rocoads.com', 'rtbreachads.com', 'rubiconproject.com', 'rugbymentalads.com',
  'sambaads.com', 'samsungads.com', 'satisfactorybroadformidable.com', 'scorchads.com',
  'scorecardresearch.com', 'seadform.net', 'seaofads.com', 'sensible-ads.com',
  'servemeads.com', 'server4ads.com', 'serverads.net', 'sf-ads.io',
  'sh.st', 'sharethrough.com', 'shorte.st', 'sizmek.com',
  'skeetads.com', 'skipvideoads.com', 'smart1adserver.com', 'smartadserver.com',
  'smartclip.com', 'smartclip.net', 'smartnews-ads.com', 'smartyads.com',
  'smentbrads.info', 'softonicads.com', 'softpopads.com', 'soliads.io',
  'soliads.online', 'sourcepoint.com', 'sovrn.com', 'spareforads.top',
  'spotx.tv', 'spotxchange.com', 'springserve.com', 'srvupads.com',
  'ssp.yahoo.com', 'star-advertising.com', 'static.ads-twitter.com', 'statsforads.com',
  'steroidslaughteradvertise.com', 'stopblockads.com', 'studads.com', 'sublimemedia.net',
  'sunmediaads.com', 'swak-adguard.pro', 'syndication.twitter.com', 'synsads.com',
  'taboola.com', 'taboolasyndication.com', 'takeads.com', 'tapjoyads.com',
  'targetads.io', 'taroads.com', 'teads.com', 'teads.tv',
  'text-link-ads.com', 'theadvertiser.com', 'tnpads.xyz', 'toboads.com',
  'tokenads.com', 'tomladvert.com', 'topadvert.ru', 'toptopleads.com',
  'toroadvertising.com', 'toroadvertisingmedia.com', 'tossoffads.com', 'tpc.googlesyndication.com',
  'tpdads.com', 'tpmedia-reactads.com', 'trafficfactory.biz', 'trafficholder.com',
  'trafficjunky.com', 'trafficjunky.net', 'triplelift.com', 'trmads.eu',
  'tronads.io', 'tsadvertising.com', 'tubeadvertising.eu', 'tubecorporate.com',
  'turn.com', 'twads.gg', 'twistads.com', 'uads.cc',
  'undertone.com', 'universalads.com', 'uprivaladserver.net', 'usedownloads.com',
  'vdo.ai', 'viads.com', 'viads.net', 'vidads.gr',
  'vipads.live', 'visiads.com', 'vlogerads.com', 'vrtzads.com',
  'web3ads.net', 'webads.co.nz', 'webads.eu', 'webads.media',
  'webads.nl', 'webadserver.net', 'whaleads.com', 'wolfspreads.com',
  'wtg-ads.com', 'wwads.cn', 'xapads.com', 'xcelsiusadserver.com',
  'xleads.digital', 'xmladserver.com', 'yandexadexchange.net', 'yieldads.com',
  'yieldbot.com', 'yieldlab.com', 'yieldlab.net', 'yieldmo.com',
  'yoads.net', 'yoc-adserver.com', 'yourquickads.com', 'yuhuads.com',
  'yummyadvertiseexploded.com', 'yuppads.com', 'yuppyads.com', 'yvmads.com',
  'za.gl', 'zaimads.com', 'zeads.com', 'zerads.com',
  'zergnet.com',
  };

  bool _isAdDomain(String url) {
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return false;
      final host = uri.host.toLowerCase();
      if (host.isEmpty) return false;
      if (_kBlockedDomains.contains(host)) return true;
      final parts = host.split('.');
      for (int i = 1; i < parts.length - 1; i++) {
        if (_kBlockedDomains.contains(parts.sublist(i).join('.'))) return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  const _kAdBlockJs = r"""
(function() {
  if (window.__watchtowerAdBlockActive) return;
  window.__watchtowerAdBlockActive = true;

  // ── Blocked network patterns ─────────────────────────────────────────────────
  var _blockedPatterns = [
    'doubleclick','googlesyndication','googleadservices','googletagservices','adservice.google',
    'pagead','adnxs','appnexus','taboola','outbrain',
    'popads','adsterra','propellerads','media.net','smartadserver',
    'rubiconproject','openx','criteo','pubmatic','adroll',
    'trafficjunky','exoclick','juicyads','ero-advertising','plugrush',
    'clickadu','trafficholder','adspyglass','hilltopads','adnium',
    'triplelift','sovrn','spotxchange','spotx.tv','sharethrough',
    'teads','indexexchange','casalemedia','adform','districtm',
    'moatads','fundingchoicesmessages.google','prebid','vdo.ai','adinplay',
    'mgid','zergnet','coinhive','cryptoloot','adf.ly',
    'ouo.io','clkmon','clkrev','conversantmedia','flashtalking',
    'sizmek','rhythmone','33across','undertone','yieldmo',
    'yieldbot','springserve','innovid','smartclip','freewheel',
    'yieldlab','smaato','applovin','mopub','mintegral',
    'fyber','inmobi','chartboost','vungle','tapjoy',
    'ironsrc','ironsource','cpmstar','sublimemedia','adsrvr',
    'bidswitch','quantserve','scorecardresearch','comscore','nielsen',
    'appsflyer','kochava','branch.io','adjust.com','amplitude.com',
    'mixpanel.com','hotjar.com','fullstory.com','mouseflow','onetrust',
    'quantcast','cookielaw','didomi','sourcepoint','amazon-adsystem',
    'lijit','turn.com','lkqd','emxdgt','adloox',
    'adsafeprotected','moatpixel','revcontent','nativo','plista',
    'ligatus','adblade','adbuddiz','adcolony','admixer',
    'adtegrity','adspeed','tubecorporate','trafficfactory','trafficstarr',
    'seedr.cc','streamtape','vidstreaming','coinzilla','cointraffic',
    'cryptoads','a-ads.com','popunder','popcash','adcash',
    'admanager','googletagmanager','clarity.ms','newrelic.com','nr-data.net',
    'segment.com','segment.io',
  ];

  function _isBlocked(url) {
    if (!url) return false;
    var u = url.toLowerCase();
    for (var i=0; i<_blockedPatterns.length; i++) {
      if (u.indexOf(_blockedPatterns[i]) !== -1) return true;
    }
    return false;
  }

  // ── Block fetch ──────────────────────────────────────────────────────────────
  var _origFetch = window.fetch;
  window.fetch = function(resource, init) {
    var url = (typeof resource === 'string') ? resource : (resource && resource.url) || '';
    if (_isBlocked(url)) return new Promise(function(_, rej) { rej(new TypeError('blocked')); });
    return _origFetch.apply(this, arguments);
  };

  // ── Block XMLHttpRequest ─────────────────────────────────────────────────────
  var _origOpen = XMLHttpRequest.prototype.open;
  XMLHttpRequest.prototype.open = function(method, url) {
    if (_isBlocked(url)) {
      this._wtBlocked = true;
    }
    return _origOpen.apply(this, arguments);
  };
  var _origSend = XMLHttpRequest.prototype.send;
  XMLHttpRequest.prototype.send = function() {
    if (this._wtBlocked) return;
    return _origSend.apply(this, arguments);
  };

  // ── Block window.open / popups / alerts ──────────────────────────────────────
  try { window.open = function() { return null; }; } catch(e) {}
  try { window.alert = function() {}; } catch(e) {}
  try { window.confirm = function() { return true; }; } catch(e) {}
  try { window.prompt = function() { return ''; }; } catch(e) {}

  // ── CSS rules ───────────────────────────────────────────────────────────────
  var style = document.createElement('style');
  style.id = '__watchtower_adblock_css';
  style.textContent = `
    .ad,.ads,.ad-container,.ad-wrapper,.ad-slot,.ad-unit,.ads-container,
    .advertisement,.advert,.advertise,.advertising,.sponsor,.sponsored,
    .popup,.pop-up,.interstitial,.overlay-ad,.ad-overlay,.modal-ad,
    .gdpr-banner,.gdpr-overlay,.cookie-banner,.cookie-notice,.cookie-popup,
    .consent-banner,.consent-popup,.newsletter-popup,.newsletter-modal,
    .pushad,.push-ad,.sticky-ad,.fixed-ad,.floating-ad,.banner-ad,
    .vid-container>div[style*="position:fixed"],
    div[style*="position:fixed"][style*="z-index:9"],
    div[style*="position:fixed"][style*="z-index: 9"],
    [class*="google-ads"],[class*="google_ads"],[id*="google_ads"],
    [class*="adsense"],[id*="adsense"],
    [class*="adsbygoogle"],[id*="adsbygoogle"],
    [id^="div-gpt-ad"],[id^="gpt-ad"],
    iframe[src*="doubleclick"],iframe[src*="googlesyndication"],
    iframe[src*="adnxs"],iframe[src*="ads."],iframe[src*="/ads/"],
    iframe[src*="adservice"],iframe[src*="pagead"],iframe[src*="taboola"],
    iframe[src*="outbrain"],iframe[src*="criteo"],iframe[src*="popads"],
    div[id^="ad_"],div[id^="ads_"],div[class^="ad_"],div[class^="ads_"],
    ins.adsbygoogle,
    #ad,#ads,#banner-ad,#sponsor,#sponsored,#popup,#interstitial,
    #cookie-banner,#gdpr-overlay,#consent-modal,#newsletter-popup,
    .overlay,.modal-overlay,.bg-overlay:not(.video-overlay) {
      display:none!important;
      visibility:hidden!important;
      opacity:0!important;
      pointer-events:none!important;
      height:0!important;
      max-height:0!important;
      overflow:hidden!important;
    }
    body { overflow: auto !important; }
    html, body { position: static !important; }
  `;
  (document.head || document.documentElement).appendChild(style);

  // ── DOM cleaning ─────────────────────────────────────────────────────────────
  var adSelectors = [
    'iframe[src*="ads"]','iframe[src*="doubleclick"]',
    'iframe[src*="googlesyndication"]','iframe[src*="adnxs"]',
    'iframe[src*="adservice"]','iframe[src*="pagead"]',
    'iframe[src*="taboola"]','iframe[src*="outbrain"]',
    'ins.adsbygoogle','[id^="div-gpt-ad"]',
    '[class*="overlay-ad"]','[class*="modal-ad"]',
    '[class*="gdpr"]','[class*="consent"]','[class*="cookie-banner"]',
    '[class*="newsletter-popup"]','[data-ad]','[data-ads]','[data-adunit]',
    '.adsbygoogle','#cookie-banner','#gdpr-overlay','#consent-modal',
    '[class*="popup-ad"]','[class*="ad-popup"]','[id*="popup-ad"]'
  ];

  function removeAdNodes() {
    adSelectors.forEach(function(sel) {
      try {
        document.querySelectorAll(sel).forEach(function(el) {
          try { el.remove(); } catch(e) {}
        });
      } catch(e) {}
    });
    document.querySelectorAll('div,section,aside,span').forEach(function(el) {
      try {
        var c = (el.className||'').toLowerCase();
        var i = (el.id||'').toLowerCase();
        if (/\bad\b|^ads$|advert|adsense|adsbygoogle|sponsor|popup|gdpr|consent|cookie.banner|interstitial/.test(c+' '+i)) {
          if (el.offsetHeight < 500 || /popup|modal|interstitial|overlay/.test(c+' '+i)) {
            el.style.cssText = 'display:none!important;height:0!important;overflow:hidden!important;';
          }
        }
        // Remove fixed/absolute fullscreen overlays
        if (/fixed|absolute/.test(getComputedStyle(el).position||'')) {
          var z = parseInt(getComputedStyle(el).zIndex||'0');
          if (z > 9999 && el.offsetHeight > 200) {
            var tag = el.tagName.toLowerCase();
            if (tag !== 'video' && tag !== 'canvas') {
              el.style.cssText = 'display:none!important;';
            }
          }
        }
      } catch(e) {}
    });
  }

  removeAdNodes();
  document.addEventListener('DOMContentLoaded', removeAdNodes);
  setTimeout(removeAdNodes, 300);
  setTimeout(removeAdNodes, 800);
  setTimeout(removeAdNodes, 2000);
  setTimeout(removeAdNodes, 5000);
  setTimeout(removeAdNodes, 10000);

  // ── MutationObserver — catch dynamic ads ────────────────────────────────────
  var observer = new MutationObserver(function(mutations) {
    var dirty = false;
    mutations.forEach(function(m) {
      m.addedNodes.forEach(function(node) {
        if (node.nodeType !== 1) return;
        dirty = true;
        var c = (node.className||'').toLowerCase();
        var i = (node.id||'').toLowerCase();
        var src = (node.src||node.getAttribute&&node.getAttribute('src')||'').toLowerCase();
        if (/\bad\b|^ads$|advert|adsense|adsbygoogle|sponsor|popup|gdpr|consent|doubleclick|googlesyndication|taboola|outbrain|criteo/.test(c+' '+i+' '+src)) {
          try { node.remove(); return; } catch(e) {
            try { node.style.display='none'; } catch(e2) {}
          }
        }
        try {
          node.querySelectorAll && adSelectors.forEach(function(sel) {
            node.querySelectorAll(sel).forEach(function(child) {
              try { child.remove(); } catch(e) {}
            });
          });
        } catch(e) {}
      });
    });
    if (dirty) {
      try {
        document.querySelectorAll('div[style*="z-index: 2147483647"],div[style*="z-index:2147483647"]').forEach(function(el) {
          if (el.tagName !== 'VIDEO' && el.tagName !== 'CANVAS') {
            try { el.remove(); } catch(e) {}
          }
        });
      } catch(e) {}
    }
  });
  try {
    observer.observe(document.documentElement, { childList: true, subtree: true });
  } catch(e) {}
})();
""";

// ── Element picker JS (injected on demand) ────────────────────────────────────
const _kPickerJs = r"""
(function() {
  if (window.__watchtowerPickerActive) return;
  window.__watchtowerPickerActive = true;

  var overlay = document.createElement('div');
  overlay.id = '__wt_picker_overlay';
  overlay.style.cssText = 'position:fixed;top:0;left:0;width:100%;height:100%;z-index:2147483647;cursor:crosshair;background:rgba(255,0,0,0.05);';
  document.body.appendChild(overlay);

  var highlight = document.createElement('div');
  highlight.style.cssText = 'position:fixed;pointer-events:none;border:2px solid red;background:rgba(255,0,0,0.15);z-index:2147483646;transition:all 0.1s;box-sizing:border-box;';
  document.body.appendChild(highlight);

  function getBounds(el) {
    var r = el.getBoundingClientRect();
    return { top: r.top, left: r.left, width: r.width, height: r.height };
  }

  overlay.addEventListener('mousemove', function(e) {
    overlay.style.pointerEvents = 'none';
    var el = document.elementFromPoint(e.clientX, e.clientY);
    overlay.style.pointerEvents = 'all';
    if (!el || el === overlay || el === highlight) return;
    var b = getBounds(el);
    highlight.style.top = b.top + 'px';
    highlight.style.left = b.left + 'px';
    highlight.style.width = b.width + 'px';
    highlight.style.height = b.height + 'px';
  });

  overlay.addEventListener('click', function(e) {
    e.preventDefault();
    e.stopPropagation();
    overlay.style.pointerEvents = 'none';
    var el = document.elementFromPoint(e.clientX, e.clientY);
    overlay.style.pointerEvents = 'all';
    if (!el || el === overlay || el === highlight) return;
    var tag = el.tagName || '';
    var cls = el.className || '';
    var id = el.id || '';
    var src = el.src || el.getAttribute('src') || '';
    var info = JSON.stringify({ tag: tag, cls: cls, id: id, src: src });
    // Store for Flutter to retrieve
    window.__watchtowerPickedInfo = info;
    // Clean up
    overlay.remove();
    highlight.remove();
    window.__watchtowerPickerActive = false;
    // Notify Flutter
    try { window.flutter_inappwebview.callHandler('elementPicked', info); } catch(e2) {}
  });
})();
""";

// ─── Panel snap positions ─────────────────────────────────────────────────────

enum _PanelSnap { mini, half, full }

double _snapFraction(_PanelSnap s) {
  switch (s) {
    case _PanelSnap.mini:
      return 0.35;
    case _PanelSnap.half:
      return 0.65;
    case _PanelSnap.full:
      return 1.0;
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

/// Returns just the registrable domain+TLD (e.g. "manga-scan.fr")
String _displayHost(String rawUrl) {
  try {
    final uri = Uri.tryParse(rawUrl);
    if (uri == null || uri.host.isEmpty) return rawUrl;
    final parts = uri.host.split('.');
    if (parts.length <= 2) return uri.host;
    return parts.sublist(parts.length - 2).join('.');
  } catch (_) {
    return rawUrl;
  }
}

bool _isSecure(String rawUrl) {
  try {
    final uri = Uri.tryParse(rawUrl);
    return uri?.scheme == 'https';
  } catch (_) {
    return false;
  }
}

// ─── Main widget ──────────────────────────────────────────────────────────────

class MangaWebView extends ConsumerStatefulWidget {
  final String url;
  final String title;
  const MangaWebView({super.key, required this.url, required this.title});

  @override
  ConsumerState<MangaWebView> createState() => _MangaWebViewState();
}

class _MangaWebViewState extends ConsumerState<MangaWebView>
    with SingleTickerProviderStateMixin {
  // Desktop
  MyInAppBrowser? browser;
  Webview? _desktopWebview;
  bool isNotWebviewWindow = false;
  bool _initialized = false;

  // WebView state
  InAppWebViewController? _webViewController;
  late String _url = widget.url;
  late String _title = widget.title;
  bool _canGoback = false;
  bool _canGoForward = false;
  double _progress = 0;

  // AdBlock
  bool _adBlockEnabled = true;
  int _blockedCount = 0;
  bool _pickerMode = false;
  List<String> _blockedElements = [];

  // Footer visibility (toggled by ghost icon)
  bool _showFooter = true;

  // Night mode / text size / desktop / incognito
  bool _nightMode = false;
  int _textSizeStep = 0;
  bool _desktopMode = false;
  bool _incognitoMode = false;

  // Panel drag
  _PanelSnap _snap = _PanelSnap.full;
  double _currentFraction = 1.0;
  double _dragStartFraction = 1.0;
  double _dragStartY = 0;

  late AnimationController _animCtrl;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    );
    _animation = Tween<double>(begin: 1.0, end: 1.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic),
    );
    _animation.addListener(() {
      if (mounted) setState(() => _currentFraction = _animation.value);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    if (!kIsWeb && (Platform.isLinux || Platform.isWindows)) {
      _runWebViewDesktop();
    } else {
      setState(() => isNotWebviewWindow = true);
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    if (!kIsWeb && Platform.isLinux) {
      _desktopWebview?.close();
    } else if (browser != null) {
      if (browser!.isOpened()) browser!.close();
      browser!.dispose();
    }
    super.dispose();
  }

  // ── Desktop ───────────────────────────────────────────────────────────────

  Future<void> _runWebViewDesktop() async {
    String? ua = ref.read(userAgentStateProvider);
    if (ua == defaultUserAgent) ua = null;

    if (!kIsWeb && Platform.isLinux) {
      _desktopWebview = await WebviewWindow.create();
      final timer = Timer.periodic(const Duration(seconds: 1), (t) async {
        try {
          final cookies = await _desktopWebview!.getAllCookies();
          final ua2 =
              await _desktopWebview!.evaluateJavaScript("navigator.userAgent") ??
              "";
          final cookie = cookies.map((e) => '${e.name}=${e.value}').join(';');
          await MClient.setCookie(_url, ua2, null, cookie: cookie);
        } catch (_) {}
      });
      _desktopWebview!
        ..setBrightness(Brightness.dark)
        ..launch(widget.url)
        ..onClose.whenComplete(() {
          timer.cancel();
          if (mounted) Navigator.pop(context);
        });
    } else {
      browser = MyInAppBrowser(
        context: context,
        controller: (c) => _webViewController = c,
        onProgress: (progress) async {
          final back = await _webViewController?.canGoBack();
          final fwd = await _webViewController?.canGoForward();
          final title = await _webViewController?.getTitle();
          final url = await _webViewController?.getUrl();
          if (mounted) {
            setState(() {
              _progress = progress / 100;
              _url = url.toString();
              _title = title ?? _title;
              _canGoback = back ?? false;
              _canGoForward = fwd ?? false;
            });
          }
        },
      );
      await browser!.openUrlRequest(
        urlRequest: URLRequest(url: WebUri(widget.url)),
        settings: InAppBrowserClassSettings(
          browserSettings: InAppBrowserSettings(
            presentationStyle: ModalPresentationStyle.POPOVER,
          ),
          webViewSettings: InAppWebViewSettings(
            isInspectable: kDebugMode,
            useShouldOverrideUrlLoading: true,
            userAgent: ua,
          ),
        ),
      );
    }
  }

  // ── Panel drag ────────────────────────────────────────────────────────────

  void _onDragStart(DragStartDetails d) {
    _dragStartY = d.globalPosition.dy;
    _dragStartFraction = _currentFraction;
  }

  void _onDragUpdate(DragUpdateDetails d) {
    final screenH = MediaQuery.of(context).size.height;
    final dy = d.globalPosition.dy - _dragStartY;
    final newFraction = (_dragStartFraction - dy / screenH).clamp(0.2, 1.0);
    setState(() => _currentFraction = newFraction);
  }

  void _onDragEnd(DragEndDetails d) {
    final velocity = d.primaryVelocity ?? 0;
    _PanelSnap target;

    if (velocity > 600) {
      target = _snap == _PanelSnap.full ? _PanelSnap.half : _PanelSnap.mini;
    } else if (velocity < -600) {
      target = _snap == _PanelSnap.mini ? _PanelSnap.half : _PanelSnap.full;
    } else {
      final all = [_PanelSnap.mini, _PanelSnap.half, _PanelSnap.full];
      target = all.reduce((a, b) {
        final da = (_snapFraction(a) - _currentFraction).abs();
        final db = (_snapFraction(b) - _currentFraction).abs();
        return da < db ? a : b;
      });
    }

    if (_currentFraction < 0.25) {
      _dismiss();
      return;
    }

    _snap = target;
    _animateTo(_snapFraction(target));
  }

  void _animateTo(double target) {
    _animation = Tween<double>(begin: _currentFraction, end: target).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic),
    );
    _animCtrl.forward(from: 0);
  }

  void _dismiss() {
    _animateTo(0.0);
    Future.delayed(const Duration(milliseconds: 280), () {
      if (mounted) context.pop();
    });
  }

  // ── AdBlock ───────────────────────────────────────────────────────────────

  NavigationActionPolicy _checkAd(NavigationAction action) {
    if (!_adBlockEnabled) return NavigationActionPolicy.ALLOW;
    final url = action.request.url?.toString() ?? '';
    if (_isAdDomain(url)) {
      if (mounted) setState(() => _blockedCount++);
      return NavigationActionPolicy.CANCEL;
    }
    return NavigationActionPolicy.ALLOW;
  }

  Future<void> _injectJs() async {
    if (!_adBlockEnabled) return;
    try {
      await _webViewController?.evaluateJavascript(source: _kAdBlockJs);
    } catch (_) {}
  }

  Future<void> _activatePicker() async {
    try {
      await _webViewController?.evaluateJavascript(source: _kPickerJs);
    } catch (_) {}
  }

  Future<void> _toggleNightMode() async {
    setState(() => _nightMode = !_nightMode);
    if (_nightMode) {
      await _webViewController?.evaluateJavascript(source: r"""
(function(){
  var s=document.getElementById('__wt_night');
  if(!s){s=document.createElement('style');s.id='__wt_night';document.head.appendChild(s);}
  s.textContent='html{filter:invert(1) hue-rotate(180deg)!important;}img,video,canvas{filter:invert(1) hue-rotate(180deg)!important;}';
})();
""");
    } else {
      await _webViewController?.evaluateJavascript(source:
          "var s=document.getElementById('__wt_night');if(s)s.remove();");
    }
  }

  Future<void> _cycleTextSize() async {
    _textSizeStep = (_textSizeStep + 1) % 3;
    final sizes = ['100%', '125%', '150%'];
    final labels = ['Normal', 'Grand', 'Très grand'];
    await _webViewController?.evaluateJavascript(source: """
(function(){
  var s=document.getElementById('__wt_textsize');
  if(!s){s=document.createElement('style');s.id='__wt_textsize';document.head.appendChild(s);}
  s.textContent='html{font-size:${sizes[_textSizeStep]}!important;}';
})();
""");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Taille du texte : ${labels[_textSizeStep]}'),
        duration: const Duration(seconds: 1),
      ));
    }
  }

  Future<void> _toggleIncognito() async {
    setState(() => _incognitoMode = !_incognitoMode);
    if (_incognitoMode) {
      await CookieManager.instance().deleteAllCookies();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mode incognito activé — cookies effacés'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mode incognito désactivé'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _toggleDesktopMode() async {
    setState(() => _desktopMode = !_desktopMode);
    const desktopUA =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';
    await _webViewController?.setSettings(
      settings: InAppWebViewSettings(
        userAgent: _desktopMode ? desktopUA : null,
      ),
    );
    await _webViewController?.reload();
  }

  void _openTranslation() {
    final encoded = Uri.encodeComponent(_url);
    InAppBrowser.openWithSystemBrowser(
        url: WebUri('https://translate.google.com/translate?u=$encoded'));
  }

  void _openDownload() {
    InAppBrowser.openWithSystemBrowser(url: WebUri(_url));
  }

  void _copyUrlAsBookmark() {
    Clipboard.setData(ClipboardData(text: _url));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content: Text('URL copiée dans le presse-papier'),
          duration: Duration(seconds: 2)),
    );
  }

  void _showQrCode() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
        title: Text('QR Code',
            style: TextStyle(
                color: isDark ? Colors.white : Colors.black87, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_url,
                style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            Text('Ouvrez l\'URL dans un générateur QR externe',
                style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _copyUrlAsBookmark();
            },
            child: const Text('Copier URL'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  void _toggleOrientation() {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    if (isLandscape) {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    } else {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    }
    Navigator.of(context).pop();
  }

  Future<void> _injectHideRule(String css) async {
    final js = '''
(function(){
  var s=document.getElementById('__wt_custom_hide')||document.createElement('style');
  s.id='__wt_custom_hide';
  s.textContent+='$css{display:none!important;}';
  (document.head||document.documentElement).appendChild(s);
})();
''';
    try {
      await _webViewController?.evaluateJavascript(source: js);
    } catch (_) {}
  }

  void _showPickedElementDialog(String info) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String cssId = '';
    String cssClass = '';
    String domain = '';
    try {
      final m = RegExp(r'"id":"([^"]*)"').firstMatch(info);
      final c = RegExp(r'"cls":"([^"]*)"').firstMatch(info);
      final s = RegExp(r'"src":"([^"]*)"').firstMatch(info);
      cssId = m?.group(1) ?? '';
      cssClass = (c?.group(1) ?? '').split(' ').first;
      final src = s?.group(1) ?? '';
      if (src.isNotEmpty) {
        final uri = Uri.tryParse(src);
        domain = uri?.host ?? '';
      }
    } catch (_) {}

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2C2C2E) : Colors.white,
        title: Text('Élément sélectionné', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16)),
        content: Text('Que voulez-vous faire ?', style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.black54, fontSize: 13)),
        actions: [
          if (cssId.isNotEmpty)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _injectHideRule('#$cssId');
                setState(() => _blockedElements.add('#$cssId'));
              },
              child: Text('Masquer #$cssId', style: const TextStyle(color: Colors.orange)),
            ),
          if (cssClass.isNotEmpty)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _injectHideRule('.$cssClass');
                setState(() => _blockedElements.add('.$cssClass'));
              },
              child: Text('Masquer .$cssClass', style: const TextStyle(color: Colors.orange)),
            ),
          if (domain.isNotEmpty)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _blockedElements.add(domain);
                  _blockedCount++;
                });
              },
              child: Text('Bloquer $domain', style: const TextStyle(color: Colors.red)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  void _showAdMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AdBlockSheet(
        enabled: _adBlockEnabled,
        blockedCount: _blockedCount,
        onToggle: (v) {
          setState(() => _adBlockEnabled = v);
          Navigator.pop(context);
        },
        onReset: () {
          setState(() => _blockedCount = 0);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showMoreMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: false,
      builder: (sheetCtx) {
        // Use sheetCtx (the modal's own context) to pop the bottom sheet.
        // Using the outer widget context causes a navigator mismatch with
        // GoRouter nested navigators, making it look like buttons don't work.
        void dismiss() {
          if (Navigator.of(sheetCtx).canPop()) {
            Navigator.of(sheetCtx).pop();
          }
        }

        return _MoreSheet(
          adEnabled: _adBlockEnabled,
          blockedCount: _blockedCount,
          blockedElements: _blockedElements,
          nightMode: _nightMode,
          desktopMode: _desktopMode,
          textSizeStep: _textSizeStep,
          incognito: _incognitoMode,
          onCopyUrl: () {
            dismiss();
            Clipboard.setData(ClipboardData(text: _url));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('URL copiée'), duration: Duration(seconds: 2)),
            );
          },
          onShare: () {
            dismiss();
            final box = context.findRenderObject() as RenderBox?;
            SharePlus.instance.share(
              ShareParams(
                text: _url,
                sharePositionOrigin: box != null
                    ? box.localToGlobal(Offset.zero) & box.size
                    : null,
              ),
            );
          },
          onOpenBrowser: () {
            dismiss();
            InAppBrowser.openWithSystemBrowser(url: WebUri(_url));
          },
          onViewSource: () {
            dismiss();
            _webViewController?.evaluateJavascript(source: "document.documentElement.outerHTML");
          },
          onFindInPage: () {
            dismiss();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Recherche dans la page non disponible'), duration: Duration(seconds: 2)),
            );
          },
          onToggleAdBlock: () {
            setState(() => _adBlockEnabled = !_adBlockEnabled);
            if (_adBlockEnabled) _injectJs();
            dismiss();
          },
          onPickElement: () {
            dismiss();
            setState(() => _pickerMode = true);
            _activatePicker();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Tap sur un élément pour le bloquer'), duration: Duration(seconds: 4)),
            );
          },
          onResetRules: () {
            setState(() { _blockedCount = 0; _blockedElements.clear(); });
            dismiss();
          },
          onClearCookies: () {
            dismiss();
            CookieManager.instance().deleteAllCookies();
            MClient.deleteAllCookies(_url);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Cookies effacés'), duration: Duration(seconds: 2)),
            );
          },
          onFullscreen: () {
            dismiss();
            _snap = _PanelSnap.full;
            _animateTo(1.0);
          },
          onUserAgent: () {
            dismiss();
            _toggleDesktopMode();
          },
          onNetworkLog: () {
            dismiss();
            _showAdMenu();
          },
          onNightMode: () {
            dismiss();
            _toggleNightMode();
          },
          onTextSize: () {
            dismiss();
            _cycleTextSize();
          },
          onDesktopMode: () {
            dismiss();
            _toggleDesktopMode();
          },
          onTranslate: () {
            dismiss();
            _openTranslation();
          },
          onDownload: () {
            dismiss();
            _openDownload();
          },
          onBookmark: () {
            dismiss();
            _copyUrlAsBookmark();
          },
          onQrCode: () {
            dismiss();
            _showQrCode();
          },
          onOrientation: () {
            dismiss();
            _toggleOrientation();
          },
          onIncognito: () {
            dismiss();
            _toggleIncognito();
          },
          onCloseWebView: () => context.pop(),
        );
      },
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Desktop: simple screen
    if (!isNotWebviewWindow && !kIsWeb && (Platform.isLinux || Platform.isWindows)) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            _title,
            style: const TextStyle(
              overflow: TextOverflow.ellipsis,
              fontWeight: FontWeight.bold,
            ),
          ),
          leading: IconButton(
            onPressed: () {
              _desktopWebview?.close();
              Navigator.pop(context);
            },
            icon: const Icon(Icons.close),
          ),
        ),
      );
    }

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _webViewController?.canGoBack() ?? false) {
          _webViewController?.goBack();
        } else {
          if (mounted) context.pop();
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        // ── Top bar: address + close ──────────────────────────────────
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(54),
          child: _BrowserHeader(
            url: _url,
            title: _title,
            progress: _progress,
            isDark: isDark,
            cs: cs,
            adEnabled: _adBlockEnabled,
            blockedCount: _blockedCount,
            showFooter: _showFooter,
            incognito: _incognitoMode,
            onToggleFooter: () => setState(() => _showFooter = !_showFooter),
            onRefresh: () => _webViewController?.reload(),
          ),
        ),
        // ── WebView body ──────────────────────────────────────────────
        body: kIsWeb || !Platform.isWindows
            ? InAppWebView(
                            webViewEnvironment: webViewEnvironment,
                            initialUrlRequest: URLRequest(url: WebUri(widget.url)),
                            initialSettings: InAppWebViewSettings(
                              isInspectable: kDebugMode,
                              useShouldOverrideUrlLoading: true,
                              useShouldInterceptRequest: !kIsWeb && Platform.isAndroid,
                              incognito: _incognitoMode,
                              // Transparent bg so scaffold colour shows during load
                              transparentBackground: true,
                              userAgent:
                                  ref.read(userAgentStateProvider) ==
                                          defaultUserAgent
                                      ? null
                                      : ref.read(userAgentStateProvider),
                            ),
                            onWebViewCreated: (c) {
                              _webViewController = c;
                              c.addJavaScriptHandler(
                                handlerName: 'elementPicked',
                                callback: (args) {
                                  if (!mounted) return;
                                  setState(() => _pickerMode = false);
                                  final info = args.isNotEmpty ? args[0].toString() : '';
                                  _showPickedElementDialog(info);
                                },
                              );
                            },
                            onLoadStart: (c, url) {
                              if (mounted) setState(() => _url = url.toString());
                            },
                            onLoadStop: (c, url) async {
                              if (mounted) setState(() => _url = url.toString());
                              await _injectJs();
                            },
                            onProgressChanged: (c, progress) {
                              if (mounted) {
                                setState(() => _progress = progress / 100);
                              }
                            },
                            onUpdateVisitedHistory: (c, url, _) async {
                              final ua = await c.evaluateJavascript(
                                    source: 'navigator.userAgent',
                                  ) ??
                                  '';
                              await MClient.setCookie(url.toString(), ua, c);
                              final back = await c.canGoBack();
                              final fwd = await c.canGoForward();
                              final title = await c.getTitle();
                              if (mounted) {
                                setState(() {
                                  _url = url.toString();
                                  _title = title ?? _title;
                                  _canGoback = back;
                                  _canGoForward = fwd;
                                });
                              }
                            },
                            shouldOverrideUrlLoading: (c, action) async {
                              final policy = _checkAd(action);
                              if (policy == NavigationActionPolicy.CANCEL) {
                                return policy;
                              }
                              final uri = action.request.url!;
                              if (![
                                'http',
                                'https',
                                'file',
                                'chrome',
                                'data',
                                'javascript',
                                'about',
                              ].contains(uri.scheme)) {
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri);
                                  return NavigationActionPolicy.CANCEL;
                                }
                              }
                              return NavigationActionPolicy.ALLOW;
                            },
                            shouldInterceptRequest: (!kIsWeb && Platform.isAndroid)
                                ? (c, request) async {
                                    final url = request.url.toString();
                                    if (_adBlockEnabled && _isAdDomain(url)) {
                                      if (mounted) {
                                        setState(() => _blockedCount++);
                                      }
                                      return WebResourceResponse(
                                        contentType: 'text/plain',
                                        statusCode: 200,
                                        reasonPhrase: 'OK',
                                      );
                                    }
                                    return null;
                                  }
                                : null,
                          )
            : const SizedBox.shrink(),
        // ── Bottom toolbar ────────────────────────────────────────────
        bottomNavigationBar: _showFooter
            ? _BrowserToolbar(
                isDark: isDark,
                cs: cs,
                canGoBack: _canGoback,
                canGoForward: _canGoForward,
                onBack: () => _webViewController?.goBack(),
                onForward: () => _webViewController?.goForward(),
                onHome: () => _webViewController?.loadUrl(
                  urlRequest: URLRequest(url: WebUri(widget.url)),
                ),
                onTabs: _showMoreMenu,
                onMore: _showMoreMenu,
              )
            : null,
      ),
    );
  }
}

// ─── Browser header (drag handle + address bar + progress) ───────────────────

class _BrowserHeader extends StatelessWidget {
  final String url;
  final String title;
  final double progress;
  final bool isDark;
  final ColorScheme cs;
  final bool adEnabled;
  final int blockedCount;
  final bool showFooter;
  final bool incognito;
  final VoidCallback onToggleFooter;
  final VoidCallback onRefresh;

  const _BrowserHeader({
    required this.url,
    required this.title,
    required this.progress,
    required this.isDark,
    required this.cs,
    required this.adEnabled,
    required this.blockedCount,
    required this.showFooter,
    required this.incognito,
    required this.onToggleFooter,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final secure = _isSecure(url);
    final displayTitle = title.isNotEmpty ? title : _displayHost(url);
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.grey.shade500 : Colors.grey.shade500;

    // Left icon colour: incognito=purple, HTTPS=green, HTTP=grey
    final Color shieldColor = incognito
        ? Colors.deepPurple.shade300
        : secure
            ? (isDark ? Colors.greenAccent.shade400 : Colors.green.shade600)
            : subColor;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Address bar row — completely flat, no container/pill/box
        SizedBox(
          height: 46,
          child: Row(
            children: [
              // Left: shield (secure) or ghost (incognito) — tap = toggle footer
              GestureDetector(
                onTap: onToggleFooter,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  child: SvgPicture.asset(
                    incognito ? 'assets/icons/ghost.svg' : 'assets/icons/block-ads.svg',
                    width: 22,
                    height: 22,
                    colorFilter: ColorFilter.mode(shieldColor, BlendMode.srcIn),
                  ),
                ),
              ),

              // Title — centered, plain text, no box
              Expanded(
                child: GestureDetector(
                  onLongPress: () {
                    Clipboard.setData(ClipboardData(text: url));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Lien copié'), duration: Duration(seconds: 2)),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          displayTitle,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: textColor,
                            overflow: TextOverflow.ellipsis,
                          ),
                          maxLines: 1,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      if (adEnabled && blockedCount > 0) ...[
                        const SizedBox(width: 6),
                        Text(
                          blockedCount > 99 ? '99+' : '$blockedCount',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.greenAccent.shade400 : Colors.green.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Right: ONLY refresh icon
              GestureDetector(
                onTap: onRefresh,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  child: Icon(
                    Icons.refresh_rounded,
                    size: 22,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Progress bar
        SizedBox(
          height: 2,
          child: progress < 1.0
              ? LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(cs.primary),
                )
              : const SizedBox.shrink(),
        ),

        // Subtle divider
        Divider(
          height: 1,
          thickness: 0.5,
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ],
    );
  }
}

// ─── Bottom browser toolbar ───────────────────────────────────────────────────

class _BrowserToolbar extends StatelessWidget {
  final bool isDark;
  final ColorScheme cs;
  final bool canGoBack;
  final bool canGoForward;
  final VoidCallback onBack;
  final VoidCallback onForward;
  final VoidCallback onHome;
  final VoidCallback onTabs;
  final VoidCallback onMore;

  const _BrowserToolbar({
    required this.isDark,
    required this.cs,
    required this.canGoBack,
    required this.canGoForward,
    required this.onBack,
    required this.onForward,
    required this.onHome,
    required this.onTabs,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final dividerColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.08);
    final inactiveColor = isDark ? Colors.grey.shade700 : Colors.grey.shade400;

    return Container(
      color: bg,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Divider(height: 1, thickness: 0.5, color: dividerColor),
          SafeArea(
            top: false,
            child: SizedBox(
              height: 52,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // Back
                  _ToolbarBtn(
                    svgAsset: 'assets/icons/arrow-left.svg',
                    size: 18,
                    onTap: canGoBack ? onBack : null,
                    isDark: isDark,
                    disabledColor: inactiveColor,
                  ),
                  // Forward
                  _ToolbarBtn(
                    svgAsset: 'assets/icons/arrow-right.svg',
                    size: 18,
                    onTap: canGoForward ? onForward : null,
                    isDark: isDark,
                    disabledColor: inactiveColor,
                  ),
                  // Home
                  _ToolbarBtn(
                    svgAsset: 'assets/icons/home.svg',
                    size: 22,
                    onTap: onHome,
                    isDark: isDark,
                  ),
                  // Tabs / onglets
                  _ToolbarBtn(
                    svgAsset: 'assets/icons/number-square-one.svg',
                    size: 21,
                    onTap: onTabs,
                    isDark: isDark,
                  ),
                  // Menu (3 barres / hamburger)
                  _ToolbarBtn(
                    svgAsset: 'assets/icons/menu.svg',
                    size: 22,
                    onTap: onMore,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Reusable icon button ─────────────────────────────────────────────────────

class _ToolbarBtn extends StatelessWidget {
  final IconData? icon;
  final String? svgAsset;
  final double size;
  final VoidCallback? onTap;
  final bool isDark;
  final Color? disabledColor;

  const _ToolbarBtn({
    this.icon,
    this.svgAsset,
    required this.size,
    required this.onTap,
    required this.isDark,
    this.disabledColor,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = isDark ? Colors.white : Colors.black87;
    final color = onTap == null
        ? (disabledColor ?? (isDark ? Colors.grey.shade700 : Colors.grey.shade400))
        : activeColor;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: svgAsset != null
            ? SvgPicture.asset(
                svgAsset!,
                width: size,
                height: size,
                colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
              )
            : Icon(icon, size: size, color: color),
      ),
    );
  }
}

// ─── More options sheet (Via-style, 3 swipeable pages) ────────────────────────

class _MoreSheet extends StatefulWidget {
  final bool adEnabled;
  final int blockedCount;
  final List<String> blockedElements;
  final bool nightMode;
  final bool desktopMode;
  final int textSizeStep;
  final VoidCallback onCopyUrl;
  final VoidCallback onShare;
  final VoidCallback onOpenBrowser;
  final VoidCallback onViewSource;
  final VoidCallback onFindInPage;
  final VoidCallback onToggleAdBlock;
  final VoidCallback onPickElement;
  final VoidCallback onResetRules;
  final VoidCallback onClearCookies;
  final VoidCallback onFullscreen;
  final VoidCallback onUserAgent;
  final VoidCallback onNetworkLog;
  final VoidCallback onNightMode;
  final VoidCallback onTextSize;
  final VoidCallback onDesktopMode;
  final VoidCallback onTranslate;
  final VoidCallback onDownload;
  final VoidCallback onBookmark;
  final VoidCallback onQrCode;
  final VoidCallback onOrientation;
  final VoidCallback onIncognito;
  final VoidCallback onCloseWebView;
  final bool incognito;

  const _MoreSheet({
    required this.adEnabled,
    required this.blockedCount,
    required this.blockedElements,
    required this.nightMode,
    required this.desktopMode,
    required this.textSizeStep,
    required this.incognito,
    required this.onCopyUrl,
    required this.onShare,
    required this.onOpenBrowser,
    required this.onViewSource,
    required this.onFindInPage,
    required this.onToggleAdBlock,
    required this.onPickElement,
    required this.onResetRules,
    required this.onClearCookies,
    required this.onFullscreen,
    required this.onUserAgent,
    required this.onNetworkLog,
    required this.onNightMode,
    required this.onTextSize,
    required this.onDesktopMode,
    required this.onTranslate,
    required this.onDownload,
    required this.onBookmark,
    required this.onQrCode,
    required this.onOrientation,
    required this.onIncognito,
    required this.onCloseWebView,
  });

  @override
  State<_MoreSheet> createState() => _MoreSheetState();
}

class _MoreSheetState extends State<_MoreSheet> {
  final PageController _pageCtrl = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final iconColor = isDark ? Colors.white : Colors.black87;
    final labelColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    Widget item(IconData? icon, String label, VoidCallback onTap, {Color? accent, bool highlight = false, String? svgAsset}) {
      final effectiveColor = highlight
          ? (accent ?? (isDark ? Colors.greenAccent.shade400 : Colors.green.shade600))
          : (accent ?? iconColor);
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.translucent,
        child: SizedBox(
          width: 64,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 64,
                height: 44,
                child: Center(
                  child: svgAsset != null
                      ? SvgPicture.asset(
                          svgAsset,
                          width: 24,
                          height: 24,
                          colorFilter: ColorFilter.mode(effectiveColor, BlendMode.srcIn),
                        )
                      : Icon(icon, size: 24, color: effectiveColor),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: highlight ? effectiveColor : (accent ?? labelColor),
                  fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      );
    }

    // ── Build pages ──────────────────────────────────────────────────────────
    Widget buildPage(List<Widget> items) {
      final rows = <Widget>[];
      for (int i = 0; i < items.length; i += 5) {
        final rowItems = items.sublist(i, (i + 5).clamp(0, items.length));
        while (rowItems.length < 5) rowItems.add(const SizedBox(width: 62));
        rows.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: rowItems,
            ),
          ),
        );
      }
      return Column(children: rows);
    }

    final page1 = buildPage([
      item(null, 'Chercher', widget.onFindInPage, svgAsset: 'assets/icons/search-in-page.svg'),
      item(Icons.copy_rounded, 'Copier URL', widget.onCopyUrl),
      item(null, 'Partager', widget.onShare, svgAsset: 'assets/icons/share-2.svg'),
      item(null, 'Navigateur', widget.onOpenBrowser, svgAsset: 'assets/icons/globe.svg'),
      item(null, 'Source', widget.onViewSource, svgAsset: 'assets/icons/code.svg'),
      item(null, 'Plein écran', widget.onFullscreen, svgAsset: 'assets/icons/maximize.svg'),
      item(null, 'Cookies', widget.onClearCookies, svgAsset: 'assets/icons/trash-2.svg'),
      item(null, 'User-Agent', widget.onUserAgent, svgAsset: 'assets/icons/user-agent.svg'),
      item(null, 'Réseau', widget.onNetworkLog, svgAsset: 'assets/icons/network-log.svg'),
      item(Icons.info_outline_rounded, 'À propos', () => Navigator.pop(context)),
    ]);

    final page2 = buildPage([
      item(
        null,
        widget.adEnabled
            ? (widget.blockedCount > 0 ? '${widget.blockedCount} bloqués' : 'AdBlock ON')
            : 'AdBlock OFF',
        widget.onToggleAdBlock,
        svgAsset: 'assets/icons/block-ads.svg',
        accent: widget.adEnabled ? Colors.greenAccent.shade400 : Colors.grey,
        highlight: widget.adEnabled,
      ),
      item(null, 'Sélect. élém.', widget.onPickElement, svgAsset: 'assets/icons/edit-2.svg', accent: Colors.orange),
      item(null, 'Masquer élém.', widget.onPickElement, svgAsset: 'assets/icons/eye-slash.svg'),
      item(null, 'Bloquer dom.', widget.onPickElement, svgAsset: 'assets/icons/minus-circle.svg', accent: Colors.redAccent),
      item(Icons.refresh_rounded, 'Réinitialiser', widget.onResetRules),
      item(
        null,
        widget.blockedElements.isEmpty ? 'Aucun bloqué' : '${widget.blockedElements.length} règles',
        () {},
        svgAsset: 'assets/icons/layers.svg',
      ),
      item(null, 'Nuit', widget.onNightMode,
          svgAsset: 'assets/icons/moon.svg',
          highlight: widget.nightMode,
          accent: widget.nightMode ? Colors.indigo.shade300 : null),
      item(null, 'Statistiques', () => Navigator.pop(context), svgAsset: 'assets/icons/activity.svg'),
      item(null, 'Réglages', () => Navigator.pop(context), svgAsset: 'assets/icons/settings.svg'),
      item(null, 'Whitelist', () => Navigator.pop(context), svgAsset: 'assets/icons/block-ads.svg'),
    ]);

    final textSizeLabels = ['Texte', 'Texte+', 'Texte++'];
    final page3 = buildPage([
      item(null, textSizeLabels[widget.textSizeStep], widget.onTextSize,
          svgAsset: 'assets/icons/text-size.svg',
          highlight: widget.textSizeStep > 0,
          accent: widget.textSizeStep > 0 ? Colors.blue.shade400 : null),
      item(Icons.brightness_6_rounded, 'Luminosité', () => Navigator.pop(context)),
      item(null, 'Orientation', widget.onOrientation, svgAsset: 'assets/icons/orientation.svg'),
      item(null, 'Télécharger', widget.onDownload, svgAsset: 'assets/icons/download.svg'),
      item(null, 'Favoris', widget.onBookmark, svgAsset: 'assets/icons/star.svg'),
      item(null, 'Accueil', () => Navigator.pop(context), svgAsset: 'assets/icons/home.svg'),
      item(null, 'QR Code', widget.onQrCode, svgAsset: 'assets/icons/qr-code.svg'),
      item(null, 'Traduction', widget.onTranslate, svgAsset: 'assets/icons/translate.svg'),
      item(null, 'Bureau', widget.onDesktopMode,
          svgAsset: 'assets/icons/desktop.svg',
          highlight: widget.desktopMode,
          accent: widget.desktopMode ? Colors.blue.shade400 : null),
      item(null, 'Incognito', widget.onIncognito,
          svgAsset: 'assets/icons/ghost.svg',
          highlight: widget.incognito,
          accent: widget.incognito ? Colors.deepPurple.shade300 : null),
    ]);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 14),

            // PageView — 3 pages
            SizedBox(
              height: 190,
              child: PageView(
                controller: _pageCtrl,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: page1),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: page2),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: page3),
                ],
              ),
            ),

            // Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
                  width: _page == i ? 16 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: _page == i
                        ? (isDark ? Colors.white : Colors.black87)
                        : (isDark ? Colors.white.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.2)),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),

            // Divider
            Divider(
              height: 1,
              thickness: 0.5,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.07),
            ),

            // Bottom row: power + down
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Power = close WebView entirely
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      widget.onCloseWebView();
                    },
                    child: Icon(
                      Icons.power_settings_new_rounded,
                      size: 26,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  // Down = dismiss sheet
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 30,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── AdBlock sheet ────────────────────────────────────────────────────────────

class _AdBlockSheet extends StatelessWidget {
  final bool enabled;
  final int blockedCount;
  final void Function(bool) onToggle;
  final VoidCallback onReset;

  const _AdBlockSheet({
    required this.enabled,
    required this.blockedCount,
    required this.onToggle,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF2C2C2E) : Colors.white;

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
            blurRadius: 20,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.black.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(
              children: [
                Icon(
                  Icons.shield_rounded,
                  color: enabled ? Colors.greenAccent : Colors.grey,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  'AdBlock',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const Spacer(),
                if (blockedCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.green.shade800.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$blockedCount bloqués',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? Colors.greenAccent.shade400
                            : Colors.green.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 0.5,
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.07),
          ),
          SwitchListTile(
            title: Text(
              "Activer l'AdBlock",
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              'Bloque les domaines publicitaires connus et injecte un filtre CSS/DOM',
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
              ),
            ),
            value: enabled,
            onChanged: onToggle,
            activeColor: Colors.greenAccent,
          ),
          ListTile(
            leading: Icon(
              Icons.refresh_rounded,
              size: 20,
              color: isDark ? Colors.white : Colors.black87,
            ),
            title: Text(
              'Réinitialiser le compteur',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            onTap: onReset,
            dense: true,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── Desktop InAppBrowser wrapper ─────────────────────────────────────────────

class MyInAppBrowser extends InAppBrowser {
  BuildContext context;
  void Function(InAppWebViewController) controller;
  void Function(int) onProgress;

  MyInAppBrowser({
    required this.context,
    required this.controller,
    required this.onProgress,
  }) : super(webViewEnvironment: webViewEnvironment);

  @override
  Future onBrowserCreated() async => controller.call(webViewController!);

  @override
  void onProgressChanged(progress) => onProgress.call(progress);

  @override
  void onExit() => Navigator.pop(context);

  @override
  void onLoadStop(url) async {
    if (webViewController != null) {
      final ua =
          await webViewController!.evaluateJavascript(source: 'navigator.userAgent') ??
          '';
      await MClient.setCookie(url.toString(), ua, webViewController);
    }
  }

  @override
  Future<NavigationActionPolicy> shouldOverrideUrlLoading(action) async {
    final uri = action.request.url!;
    if (!['http', 'https', 'file', 'chrome', 'data', 'javascript', 'about']
        .contains(uri.scheme)) {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return NavigationActionPolicy.CANCEL;
      }
    }
    return NavigationActionPolicy.ALLOW;
  }
}
