import 'dart:async';
import 'dart:convert';
import 'dart:io' if (dart.library.js_interop) 'package:watchtower/utils/io_stub.dart';
import 'dart:typed_data';
import 'dart:ui' show ImageFilter;

import 'package:desktop_webview_window/desktop_webview_window.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:isar_community/isar.dart';
import 'package:watchtower/main.dart';
import 'package:watchtower/models/chapter.dart';
import 'package:watchtower/models/manga.dart';
import 'package:watchtower/modules/anime/anime_player_view.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:watchtower/services/mini_webview_state.dart';
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

  const _kJsBlockPatterns = [
    'doubleclick', 'googlesyndication', 'googleadservices', 'googletagservices',
    'adservice.google', 'pagead', 'adnxs', 'appnexus', 'taboola', 'outbrain',
    'popads', 'adsterra', 'propellerads', 'media.net', 'smartadserver',
    'rubiconproject', 'openx', 'criteo', 'pubmatic', 'adroll',
    'trafficjunky', 'exoclick', 'juicyads', 'ero-advertising', 'plugrush',
    'clickadu', 'trafficholder', 'hilltopads', 'adnium', 'getads.online',
    'track.getads', 'popunder', 'popcash', 'adcash', 'admanager',
    'googletagmanager', 'coinzilla', 'cointraffic', 'popadscdn',
    'servedbyadbutler', 'revcontent', 'mgid', 'zergnet', 'sharethrough',
    'moatads', 'adsafeprotected', 'quantserve', 'scorecardresearch',
    'amplitude.com', 'mixpanel.com', 'hotjar.com', 'fullstory.com',
    'onetrust', 'cookielaw', 'didomi', 'sourcepoint',
  ];

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
      final lc = url.toLowerCase();
      for (final p in _kJsBlockPatterns) {
        if (lc.contains(p)) return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  bool _isAdUrl(String url) {
    if (_isAdDomain(url)) return true;
    try {
      final uri = Uri.tryParse(url);
      if (uri == null) return false;
      final host = uri.host.toLowerCase();
      // Block tracking/redirect domains by host prefix
      if (RegExp(r'^(track|click|redirect|redir|go|link|out|aff|ref|promo)\.')
          .hasMatch(host)) return true;
      // Block URLs that look like tracker redirects (z=, cs=, refid= together)
      final p = uri.queryParameters;
      if (p.containsKey('z') && (p.containsKey('cs') || p.containsKey('pu') || p.containsKey('refid'))) {
        return true;
      }
    } catch (_) {}
    return false;
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

  // ── Block history/location changes to ad domains ─────────────────────────────
  try {
    var _origPush = history.pushState.bind(history);
    var _origReplace = history.replaceState.bind(history);
    history.pushState = function(s, t, url) {
      if (_isBlocked(String(url||''))) return;
      return _origPush(s, t, url);
    };
    history.replaceState = function(s, t, url) {
      if (_isBlocked(String(url||''))) return;
      return _origReplace(s, t, url);
    };
  } catch(e) {}

  // ── Block all clicks on links going to ad/tracker domains ────────────────────
  document.addEventListener('click', function(e) {
    var el = e.target;
    for (var i = 0; i < 6 && el && el !== document; i++) {
      if (el.tagName === 'A') {
        var href = el.href || el.getAttribute('href') || '';
        if (href && _isBlocked(href)) {
          e.preventDefault(); e.stopPropagation(); e.stopImmediatePropagation();
          return false;
        }
        // Block tracker-style redirect URLs (z=, cs=, refid=, pu= parameters)
        if (href) {
          try {
            var u = new URL(href, window.location.href);
            var sp = u.searchParams;
            var isExternal = u.hostname !== window.location.hostname;
            var hasTrackerParams = (sp.has('z') && (sp.has('cs') || sp.has('pu') || sp.has('refid')));
            var hasTrackerHost = /^(track|click|redirect|redir|go|link|out|aff)\./i.test(u.hostname);
            if (isExternal && (hasTrackerParams || hasTrackerHost)) {
              e.preventDefault(); e.stopPropagation(); e.stopImmediatePropagation();
              return false;
            }
          } catch(ex) {}
        }
        break;
      }
      el = el.parentElement;
    }
  }, true);

  // ── Block touchend on "whole-page clickjack" elements ────────────────────────
  // Some sites attach onclick to document/body to redirect on any tap
  document.addEventListener('touchend', function(e) {
    // If picker is active, don't interfere
    if (window.__wtSmartPicker && window.__wtPickerActive) return;
    var el = e.target;
    if (!el) return;
    // If the element itself (or a parent) has an onclick/href going to an ad
    for (var i = 0; i < 4 && el && el !== document; i++) {
      var onclick = el.getAttribute && el.getAttribute('onclick');
      if (onclick && _isBlocked(onclick)) {
        e.preventDefault(); e.stopPropagation();
        return;
      }
      el = el.parentElement;
    }
  }, {capture: true, passive: false});

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

// ── Smart AdBlock picker JS (floating toolbar + auto-scan + touch picker) ──────
  const _kSmartPickerJs = r"""
  (function() {
    if (window.__wtSmartPicker) return;
    window.__wtSmartPicker = true;

    // ── Ad selectors for auto-scan ──────────────────────────────────────────────
    var _adSels = [
      'iframe[src*="ads"]','iframe[src*="doubleclick"]','iframe[src*="googlesyndication"]',
      'iframe[src*="adnxs"]','iframe[src*="adservice"]','iframe[src*="pagead"]',
      'iframe[src*="taboola"]','iframe[src*="outbrain"]','iframe[src*="criteo"]',
      'ins.adsbygoogle','[id^="div-gpt-ad"]','[id^="gpt-ad"]',
      '[class*="overlay-ad"]','[class*="modal-ad"]','[class*="popup-ad"]',
      '[class*="gdpr"]','[class*="consent"]','[class*="cookie-banner"]',
      '[class*="cookie-notice"]','[class*="newsletter-popup"]',
      '.adsbygoogle','#cookie-banner','#gdpr-overlay','#consent-modal',
      '[data-ad]','[data-ads]','[data-adunit]',
      'div[style*="z-index: 2147483647"]','div[style*="z-index:2147483647"]'
    ];

    // ── Floating toolbar ────────────────────────────────────────────────────────
    var bar = document.createElement('div');
    bar.id = '__wt_bar';
    bar.style.cssText = [
      'position:fixed','bottom:72px','left:50%','transform:translateX(-50%)',
      'background:rgba(20,20,20,0.94)','color:#fff',
      'border-radius:28px','padding:7px 14px',
      'display:flex','align-items:center','gap:10px',
      'z-index:2147483645',
      'font-family:-apple-system,BlinkMacSystemFont,sans-serif','font-size:12px',
      'box-shadow:0 4px 28px rgba(0,0,0,0.5)',
      'user-select:none','-webkit-user-select:none',
      'touch-action:none','backdrop-filter:blur(10px)',
      '-webkit-backdrop-filter:blur(10px)'
    ].join(';');

    function mkBtn(txt, bg) {
      var b = document.createElement('button');
      b.textContent = txt;
      b.style.cssText = 'background:'+(bg||'rgba(255,255,255,0.12)')+';color:#fff;'
        +'border:1px solid rgba(255,255,255,0.2);border-radius:16px;'
        +'padding:4px 11px;cursor:pointer;font-size:11.5px;white-space:nowrap;'
        +'-webkit-tap-highlight-color:transparent;';
      return b;
    }

    var autoBtn  = mkBtn('⚡ Auto');
    var pickBtn  = mkBtn('🎯 Picker');
    var countLbl = document.createElement('span');
    countLbl.style.cssText = 'font-size:11px;color:rgba(255,255,255,0.65);white-space:nowrap;min-width:56px;text-align:center;';
    countLbl.textContent = '0 bloqué';
    var closeBtn = mkBtn('✕', 'transparent');
    closeBtn.style.border = 'none';
    closeBtn.style.color = 'rgba(255,255,255,0.5)';
    closeBtn.style.padding = '4px 2px';

    bar.appendChild(autoBtn);
    bar.appendChild(pickBtn);
    bar.appendChild(countLbl);
    bar.appendChild(closeBtn);
    (document.body || document.documentElement).appendChild(bar);

    // ── Highlight overlay ───────────────────────────────────────────────────────
    var hl = document.createElement('div');
    hl.id = '__wt_hl';
    hl.style.cssText = 'position:fixed;pointer-events:none;border:2px solid rgba(255,70,70,0.9);'
      +'background:rgba(255,40,40,0.1);z-index:2147483644;box-sizing:border-box;'
      +'border-radius:4px;display:none;transition:top .08s,left .08s,width .08s,height .08s;';
    (document.body || document.documentElement).appendChild(hl);

    var hlLabel = document.createElement('div');
    hlLabel.id = '__wt_hl_lbl';
    hlLabel.style.cssText = 'position:fixed;background:rgba(220,40,40,0.93);color:#fff;'
      +'font-size:10px;font-family:-apple-system,sans-serif;padding:1px 7px;border-radius:3px;'
      +'pointer-events:none;z-index:2147483646;display:none;'
      +'max-width:180px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap;';
    (document.body || document.documentElement).appendChild(hlLabel);

    // ── State ───────────────────────────────────────────────────────────────────
    var blocked = 0;
    var pickerOn = false;
    var lastEl = null;

    function updateCount() {
      countLbl.textContent = blocked + ' bloqué' + (blocked !== 1 ? 's' : '');
    }

    function blockEl(el) {
      if (!el || el.id && el.id.startsWith('__wt')) return;
      try {
        el.style.setProperty('display','none','important');
        blocked++;
        updateCount();
        var info = JSON.stringify({
          tag: el.tagName || '',
          cls: (el.className && el.className.toString ? el.className.toString() : '').slice(0,80),
          id: el.id || '',
          src: (el.src || (el.getAttribute && el.getAttribute('src')) || '').slice(0,120),
          auto: false
        });
        try { window.flutter_inappwebview.callHandler('elementPicked', info); } catch(e2) {}
      } catch(e) {}
    }

    // ── Auto-scan ───────────────────────────────────────────────────────────────
    function autoScan() {
      var found = 0;
      _adSels.forEach(function(sel) {
        try {
          document.querySelectorAll(sel).forEach(function(el) {
            if (el.id && el.id.startsWith('__wt')) return;
            if (!el.offsetParent && el.offsetWidth === 0) return;
            el.style.setProperty('display','none','important');
            found++; blocked++;
          });
        } catch(e) {}
      });
      // Heuristic: class/id contains ad keywords
      document.querySelectorAll('div,section,aside,article').forEach(function(el) {
        if (el.id && el.id.startsWith('__wt')) return;
        var c = ((el.className && el.className.toString ? el.className.toString() : '')+' '+(el.id||'')).toLowerCase();
        if (/ad|ads|advert|adsense|adsbygoogle|sponsor(?:ed)?|popup|gdpr|consent|cookie.banner|interstitial/.test(c)) {
          var h = el.offsetHeight;
          if (h > 0 && h < 500) {
            el.style.setProperty('display','none','important');
            found++; blocked++;
          }
        }
        // Large fixed/absolute overlays with high z-index
        try {
          var cs = window.getComputedStyle(el);
          var pos = cs.position;
          if ((pos === 'fixed' || pos === 'absolute') && parseInt(cs.zIndex || '0') > 999) {
            var h2 = el.offsetHeight;
            var w2 = el.offsetWidth;
            var tag = (el.tagName||'').toLowerCase();
            if (tag !== 'video' && tag !== 'canvas' && w2 > 200 && h2 > 100) {
              el.style.setProperty('display','none','important');
              found++; blocked++;
            }
          }
        } catch(e) {}
      });
      updateCount();
      return found;
    }

    // ── Full-screen transparent overlay (captures all touches in picker mode) ───
    var overlay = document.createElement('div');
    overlay.id = '__wt_overlay';
    overlay.style.cssText = 'position:fixed;top:0;left:0;width:100%;height:100%;'
      +'z-index:2147483642;display:none;cursor:crosshair;'
      +'-webkit-tap-highlight-color:transparent;touch-action:none;';
    (document.body || document.documentElement).appendChild(overlay);
    window.__wtPickerActive = false;

    // ── Picker mode touch/mouse handlers ────────────────────────────────────────
    function getXY(e) {
      if (e.touches && e.touches.length) return [e.touches[0].clientX, e.touches[0].clientY];
      if (e.changedTouches && e.changedTouches.length) return [e.changedTouches[0].clientX, e.changedTouches[0].clientY];
      return [e.clientX, e.clientY];
    }

    function onMove(e) {
      if (!pickerOn) return;
      e.preventDefault(); e.stopPropagation();
      var xy = getXY(e);
      overlay.style.pointerEvents = 'none';
      bar.style.pointerEvents = 'none';
      hl.style.display = 'none';
      var el = document.elementFromPoint(xy[0], xy[1]);
      overlay.style.pointerEvents = 'auto';
      bar.style.pointerEvents = 'auto';
      if (!el || el === bar || el === hl || el === hlLabel || el === overlay || (el.id && el.id.startsWith('__wt'))) {
        hl.style.display = 'none'; hlLabel.style.display = 'none'; return;
      }
      lastEl = el;
      var r = el.getBoundingClientRect();
      hl.style.top = r.top + 'px'; hl.style.left = r.left + 'px';
      hl.style.width = r.width + 'px'; hl.style.height = r.height + 'px';
      hl.style.display = 'block';
      var tag = (el.tagName||'').toLowerCase();
      var idStr = el.id ? '#'+el.id.slice(0,20) : '';
      var clsStr = el.className && el.className.toString ? '.'+el.className.toString().split(' ')[0].slice(0,20) : '';
      hlLabel.textContent = tag + (idStr || clsStr);
      hlLabel.style.top = Math.max(0, r.top - 18) + 'px';
      hlLabel.style.left = Math.max(0, r.left) + 'px';
      hlLabel.style.display = 'block';
    }

    function onTap(e) {
      if (!pickerOn) return;
      e.preventDefault(); e.stopPropagation(); e.stopImmediatePropagation();
      var xy = getXY(e);
      overlay.style.pointerEvents = 'none';
      bar.style.pointerEvents = 'none';
      hl.style.display = 'none';
      var el = document.elementFromPoint(xy[0], xy[1]);
      overlay.style.pointerEvents = 'auto';
      bar.style.pointerEvents = 'auto';
      if (!el || el === bar || el === hl || el === hlLabel || el === overlay || (el.id && el.id.startsWith('__wt'))) return;
      blockEl(el);
      hl.style.display = 'none'; hlLabel.style.display = 'none';
    }

    overlay.addEventListener('mousemove', onMove, {capture:true, passive:false});
    overlay.addEventListener('touchmove', onMove, {capture:true, passive:false});
    overlay.addEventListener('click', onTap, {capture:true});
    overlay.addEventListener('touchend', onTap, {capture:true});
    document.addEventListener('mousemove', onMove, true);
    document.addEventListener('touchmove', onMove, {passive:false, capture:true});
    document.addEventListener('click', onTap, true);
    document.addEventListener('touchend', onTap, {capture:true});

    // ── Button handlers ─────────────────────────────────────────────────────────
    autoBtn.addEventListener('click', function(e) {
      e.stopPropagation();
      var n = autoScan();
      autoBtn.textContent = '✅ ' + n + ' cachés';
      autoBtn.style.background = 'rgba(40,180,40,0.35)';
      setTimeout(function() {
        autoBtn.textContent = '⚡ Auto';
        autoBtn.style.background = 'rgba(255,255,255,0.12)';
      }, 2500);
    });

    pickBtn.addEventListener('click', function(e) {
      e.stopPropagation();
      pickerOn = !pickerOn;
      window.__wtPickerActive = pickerOn;
      if (pickerOn) {
        pickBtn.style.background = 'rgba(220,50,50,0.7)';
        pickBtn.style.borderColor = 'rgba(255,80,80,0.6)';
        pickBtn.textContent = '🎯 Actif';
        document.documentElement.style.cursor = 'crosshair';
        overlay.style.display = 'block';
      } else {
        pickBtn.style.background = 'rgba(255,255,255,0.12)';
        pickBtn.style.borderColor = 'rgba(255,255,255,0.2)';
        pickBtn.textContent = '🎯 Picker';
        document.documentElement.style.cursor = '';
        overlay.style.display = 'none';
        hl.style.display = 'none'; hlLabel.style.display = 'none';
      }
    });

    closeBtn.addEventListener('click', function(e) {
      e.stopPropagation();
      document.documentElement.style.cursor = '';
      window.__wtPickerActive = false;
      [bar, hl, hlLabel, overlay].forEach(function(el) { try { el.remove(); } catch(e2) {} });
      document.removeEventListener('mousemove', onMove, true);
      document.removeEventListener('touchmove', onMove, true);
      document.removeEventListener('click', onTap, true);
      document.removeEventListener('touchend', onTap, true);
      window.__wtSmartPicker = false;
      try { window.flutter_inappwebview.callHandler('pickerClosed', '{}'); } catch(e2) {}
    });

    // Auto-scan in background after load
    setTimeout(autoScan, 600);
    setTimeout(autoScan, 2000);
  })();
  """;

  // ─── Video intercept JS ───────────────────────────────────────────────────────

const String _kVideoInterceptJs = r"""
(function(){
  if(window.__wtVideoInterceptInstalled) return;
  window.__wtVideoInterceptInstalled = true;

  // Dedup: base URL (without query string) already reported this page load.
  var _seenUrls = {};

  function isMedia(url) {
    if(!url || url.length < 5) return false;
    if(url.startsWith('data:')) return false;
    var lo = url.toLowerCase().split('?')[0].split('#')[0];
    return /\.(m3u8|mp4|mkv|webm|mov|avi|mpd)(\b|$)/.test(lo) ||
           lo.indexOf('.m3u8') !== -1;
  }

  function qualityLabel(url) {
    var m = url.match(/[_\-\/](\d{3,4})[pP](?:[_\-\/.]|$)/);
    if(m) return m[1]+'p';
    if(/2160|4k|uhd/i.test(url)) return '4K';
    if(/1080/i.test(url)) return '1080p';
    if(/720/i.test(url)) return '720p';
    if(/480/i.test(url)) return '480p';
    if(/360/i.test(url)) return '360p';
    return '';
  }

  function streamType(url) {
    var lo = url.toLowerCase().split('?')[0];
    if(lo.indexOf('.m3u8') !== -1 || lo.indexOf('/hls/') !== -1 || lo.indexOf('playlist') !== -1) return 'HLS';
    if(lo.indexOf('.mpd') !== -1 || lo.indexOf('/dash/') !== -1) return 'DASH';
    if(lo.endsWith('.mp4')) return 'MP4';
    if(lo.endsWith('.webm')) return 'WebM';
    if(lo.endsWith('.mkv')) return 'MKV';
    if(lo.endsWith('.mov')) return 'MOV';
    if(lo.endsWith('.avi')) return 'AVI';
    return 'Video';
  }

  function sendUrl(url, quality, type) {
    if(!url || !isMedia(url)) return;
    var key = url.split('?')[0].split('#')[0];
    if(_seenUrls[key]) return;
    _seenUrls[key] = 1;
    var q = quality || qualityLabel(url);
    var t = type || streamType(url);
    try {
      window.flutter_inappwebview.callHandler(
        'videoIntercepted',
        JSON.stringify({
          url: url,
          quality: q,
          type: t,
          title: document.title || '',
          referer: window.location.href || ''
        })
      );
    } catch(e) {}
  }

  // ── Video element hooks ──────────────────────────────────────────────────
  function hookVideo(v) {
    if(v.__wtHooked) return;
    v.__wtHooked = true;
    function checkSrc() {
      var src = v.currentSrc || v.src || '';
      if(src && !src.startsWith('blob:') && !src.startsWith('data:')) sendUrl(src,'','');
    }
    ['loadedmetadata','canplay','play'].forEach(function(ev){
      v.addEventListener(ev, checkSrc, {passive:true});
    });
    // Check immediately if src already set
    var s = v.src || v.currentSrc || v.getAttribute('src') || '';
    if(s && !s.startsWith('blob:') && !s.startsWith('data:')) sendUrl(s,'','');
  }

  document.querySelectorAll('video').forEach(hookVideo);

  new MutationObserver(function(muts){
    muts.forEach(function(m){
      m.addedNodes.forEach(function(n){
        if(!n || n.nodeType !== 1) return;
        if(n.tagName === 'VIDEO') hookVideo(n);
        if(n.querySelectorAll) n.querySelectorAll('video').forEach(hookVideo);
      });
    });
  }).observe(document.documentElement || document.body, {childList:true,subtree:true});

  // Safari-style PiP: overlay at exact video position (position:fixed).
  // Returns Promise.resolve() for media URLs — guaranteed no Error 80.
  function _injectPipOverlay(v) {
    if(v.__wtPipOverlay) return;
    var r = v.getBoundingClientRect();
    var w = Math.max(r.width||220,120); var h = Math.max(r.height||124,80);
    var ov=document.createElement('div');
    ov.style.cssText='position:fixed;left:'+r.left+'px;top:'+r.top+'px;width:'+w+'px;height:'+h+'px;background:rgba(0,0,0,0.82);display:flex;flex-direction:column;align-items:center;justify-content:center;z-index:2147483647;pointer-events:none;gap:12px;';
    var ic=document.createElement('div');
    ic.innerHTML='<svg xmlns="http://www.w3.org/2000/svg" width="52" height="52" viewBox="0 0 24 24" fill="white" opacity="0.88"><path d="M19 11h-8v6h8v-6zm4-8H1C.45 3 0 3.45 0 4v16c0 .55.45 1 1 1h22c.55 0 1-.45 1-1V4c0-.55-.45-1-1-1zm-1 16H2V5h20v14z"/></svg>';
    var sp=document.createElement('span');
    sp.style.cssText='color:white;font-family:-apple-system,BlinkMacSystemFont,sans-serif;font-size:14px;font-weight:500;text-align:center;padding:0 24px;line-height:1.5;opacity:0.9;';
    sp.innerHTML='Cette vid\u00e9o est visionn\u00e9e<br>en Image dans l\'image.';
    ov.appendChild(ic);ov.appendChild(sp);
    document.body.appendChild(ov);
    v.__wtPipOverlay=ov;
  }
  HTMLVideoElement.prototype.play = function() {
    var src = this.currentSrc || this.src || '';
    if(src && !src.startsWith('blob:') && isMedia(src)) {
      sendUrl(src,'','');
    }
    _injectPipOverlay(this);
    return Promise.resolve();
  };

  // ── XHR hook ────────────────────────────────────────────────────────────
  var _origXHR = XMLHttpRequest.prototype.open;
  XMLHttpRequest.prototype.open = function(m, url) {
    if(typeof url === 'string') sendUrl(url,'','');
    return _origXHR.apply(this, arguments);
  };

  // ── Fetch hook ───────────────────────────────────────────────────────────
  if(window.fetch) {
    var _origFetch = window.fetch;
    window.fetch = function(r, opts) {
      var url = typeof r === 'string' ? r : (r && r.url ? r.url : '');
      if(url) sendUrl(url,'','');
      return _origFetch.apply(window, arguments);
    };
  }

  // ── hls.js — intercept loadSource() ─────────────────────────────────────
  function _patchHls(H) {
    if(!H||!H.prototype||H.prototype.__wtHlsPatched) return;
    H.prototype.__wtHlsPatched = true;
    var _orig = H.prototype.loadSource;
    if(_orig) H.prototype.loadSource = function(src) {
      sendUrl(src,'','HLS'); return _orig.apply(this,arguments);
    };
  }
  try {
    Object.defineProperty(window,'Hls',{
      configurable:true,
      get:function(){return window._wtHls;},
      set:function(v){window._wtHls=v;try{_patchHls(v);}catch(e){}}
    });
    if(window._wtHls) _patchHls(window._wtHls);
  } catch(e) {}
  try { if(typeof Hls!=='undefined'&&Hls) _patchHls(Hls); } catch(e) {}

  // ── Shaka Player — intercept load() ─────────────────────────────────────
  function _patchShaka(s) {
    if(!s||!s.Player||s.Player.prototype.__wtShakaPatched) return;
    s.Player.prototype.__wtShakaPatched = true;
    var _orig = s.Player.prototype.load;
    if(_orig) s.Player.prototype.load = function(uri) {
      sendUrl(uri,'',uri.indexOf('.m3u8')!==-1?'HLS':'DASH');
      return _orig.apply(this,arguments);
    };
  }
  try {
    Object.defineProperty(window,'shaka',{
      configurable:true,
      get:function(){return window._wtShaka;},
      set:function(v){window._wtShaka=v;try{_patchShaka(v);}catch(e){}}
    });
    if(window._wtShaka) _patchShaka(window._wtShaka);
  } catch(e) {}
  try { if(typeof shaka!=='undefined'&&shaka) _patchShaka(shaka); } catch(e) {}

  // ── Video.js — intercept src() ───────────────────────────────────────────
  function _patchVideoJs(vjs) {
    if(!vjs||!vjs.prototype||vjs.prototype.__wtVjsPatched) return;
    vjs.prototype.__wtVjsPatched = true;
    var _orig = vjs.prototype.src;
    if(_orig) vjs.prototype.src = function(src) {
      if(typeof src==='string'&&isMedia(src)) sendUrl(src,'','');
      else if(Array.isArray(src)) src.forEach(function(s){if(s&&s.src)sendUrl(s.src,s.label||'',s.type||'');});
      return _orig.apply(this,arguments);
    };
  }
  try {
    Object.defineProperty(window,'videojs',{
      configurable:true,
      get:function(){return window._wtVideojs;},
      set:function(v){window._wtVideojs=v;try{_patchVideoJs(v);}catch(e){}}
    });
    if(window._wtVideojs) _patchVideoJs(window._wtVideojs);
  } catch(e) {}
  try { if(typeof videojs!=='undefined'&&videojs) _patchVideoJs(videojs); } catch(e) {}

  // ── JW Player — intercept setup() ───────────────────────────────────────
  function _patchJwPlayer(jw) {
    if(!jw||jw.__wtJwPatched) return;
    jw.__wtJwPatched = true;
    var _origFn = jw;
    window._wtJwplayer = function() {
      var inst = _origFn.apply(this,arguments);
      if(inst&&inst.setup) {
        var _origSetup = inst.setup;
        inst.setup = function(cfg) {
          if(cfg) {
            (cfg.sources||[]).forEach(function(s){if(s&&s.file)sendUrl(s.file,s.label||'',s.type||'');});
            if(cfg.file) sendUrl(cfg.file,'','');
          }
          return _origSetup.call(this,cfg);
        };
      }
      return inst;
    };
    try { Object.assign(window._wtJwplayer, _origFn); } catch(e) {}
  }
  try {
    Object.defineProperty(window,'jwplayer',{
      configurable:true,
      get:function(){return window._wtJwplayer;},
      set:function(v){_patchJwPlayer(v);}
    });
  } catch(e) {}
  try { if(typeof jwplayer!=='undefined'&&jwplayer&&!jwplayer.__wtJwPatched) _patchJwPlayer(jwplayer); } catch(e) {}

})();
""";

  // ─── Panel snap positions ─────────────────────────────────────────────────────

enum _PanelSnap { mini, half, full }

double _snapFraction(_PanelSnap s) {
  switch (s) {
    case _PanelSnap.mini:
      return 0.075;
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
  final double initialFraction;
  const MangaWebView({
    super.key,
    required this.url,
    required this.title,
    this.initialFraction = 1.0,
  });

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
  // Undo history: each entry is {selector, displayName}
  final List<Map<String, String>> _hiddenHistory = [];

  // Video interception — floating PiP player
  final _interceptedUrls = <String>{};
  DateTime? _lastInterceptTime;
  OverlayEntry? _floatingEntry;

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
  bool _isClosing = false;

  late AnimationController _animCtrl;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _currentFraction = widget.initialFraction;
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _animation = Tween<double>(
      begin: widget.initialFraction,
      end: widget.initialFraction,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut));
    _animation.addListener(() {
      if (mounted) setState(() => _currentFraction = _animation.value);
    });
    // Enter fullscreen (hide status bar) when WebView opens
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // If restoring from dock, animate fraction from 0 → 1
    if (widget.initialFraction < 1.0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _animateTo(1.0);
      });
    }
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
    _dismissFloatingPlayer();
    // Restore system UI (status bar) when WebView closes
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
    // Toggle system UI based on panel state
    if (target == _PanelSnap.full) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
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
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) context.pop();
    });
  }

  /// Animate the panel down to 0 then push to the mini dock and pop.
  void _minimizeToDock() {
    _isClosing = true;
    _animation = Tween<double>(begin: _currentFraction, end: 0.0).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeInOut),
    );
    _animCtrl.forward(from: 0);
    _animCtrl.addStatusListener(_onMinimizeAnimDone);
  }

  void _onMinimizeAnimDone(AnimationStatus status) {
    if (status == AnimationStatus.completed && _isClosing) {
      _animCtrl.removeStatusListener(_onMinimizeAnimDone);
      final label = _title.isNotEmpty ? _title : _displayHost(_url);
      ref.read(miniWebViewProvider.notifier).push(
            MiniWebViewEntry(url: _url, title: label),
          );
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      if (mounted) context.pop();
    }
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
      await _webViewController?.evaluateJavascript(source: _kSmartPickerJs);
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

  Future<void> _injectHideRule(String css, {String? displayName}) async {
    final js = '''
(function(){
  var s=document.getElementById('__wt_custom_hide')||document.createElement('style');
  s.id='__wt_custom_hide';
  s.textContent+='$css{display:none!important;}';
  (document.head||document.documentElement).appendChild(s);
  // Store rule in window for undo support
  if(!window.__wtHiddenRules) window.__wtHiddenRules=[];
  window.__wtHiddenRules.push('$css');
})();
''';
    try {
      await _webViewController?.evaluateJavascript(source: js);
      if (mounted) {
        setState(() {
          _hiddenHistory.add({'selector': css, 'name': displayName ?? css});
        });
      }
    } catch (_) {}
  }

  Future<void> _injectRestoreRule(String css) async {
    // Re-show elements matching css selector
    final safeJs = '''
(function(){
  // Remove from custom hide style
  var s = document.getElementById('__wt_custom_hide');
  if (s) {
    s.textContent = s.textContent.replace('$css{display:none!important;}','');
  }
  // Force show matching elements
  try {
    document.querySelectorAll('$css').forEach(function(el) {
      el.style.removeProperty('display');
    });
  } catch(e) {}
  // Remove from stored rules
  if(window.__wtHiddenRules) {
    window.__wtHiddenRules = window.__wtHiddenRules.filter(function(r){return r!=='$css';});
  }
})();
''';
    try {
      await _webViewController?.evaluateJavascript(source: safeJs);
    } catch (_) {}
  }

  void _showRestoreDialog() {
    if (_hiddenHistory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun élément masqué à restaurer'), duration: Duration(seconds: 2)),
      );
      return;
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36, height: 4,
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 14, 8),
                    child: Row(
                      children: [
                        Icon(Icons.history_rounded, color: isDark ? Colors.white70 : Colors.black54, size: 20),
                        const SizedBox(width: 10),
                        Text('Éléments masqués',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87)),
                        const Spacer(),
                        TextButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            for (final rule in List<Map<String, String>>.from(_hiddenHistory)) {
                              await _injectRestoreRule(rule['selector']!);
                            }
                            if (mounted) setState(() => _hiddenHistory.clear());
                          },
                          child: const Text('Tout restaurer', style: TextStyle(color: Colors.orange, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 300),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _hiddenHistory.length,
                      itemBuilder: (_, i) {
                        final rule = _hiddenHistory[i];
                        return ListTile(
                          dense: true,
                          leading: Icon(Icons.visibility_off_outlined, size: 16, color: Colors.red.shade400),
                          title: Text(
                            rule['name'] ?? rule['selector'] ?? '',
                            style: TextStyle(fontSize: 12, color: isDark ? Colors.white : Colors.black87,
                                fontFamily: 'monospace'),
                          ),
                          trailing: TextButton(
                            onPressed: () async {
                              final sel = rule['selector']!;
                              await _injectRestoreRule(sel);
                              if (mounted) {
                                setState(() => _hiddenHistory.removeWhere((r) => r['selector'] == sel));
                                setModalState(() {});
                              }
                            },
                            child: const Text('Restaurer', style: TextStyle(color: Colors.green, fontSize: 11)),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          );
        },
      ),
    );
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
                _injectHideRule('#$cssId', displayName: '#$cssId');
                setState(() => _blockedElements.add('#$cssId'));
              },
              child: Text('Masquer #$cssId', style: const TextStyle(color: Colors.orange)),
            ),
          if (cssClass.isNotEmpty)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _injectHideRule('.$cssClass', displayName: '.$cssClass');
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
        blockedElements: _blockedElements,
        currentUrl: _url,
        hiddenCount: _hiddenHistory.length,
        onToggle: (v) {
          if (mounted) setState(() => _adBlockEnabled = v);
          if (v) _injectJs();
          Navigator.pop(context);
        },
        onReset: () {
          if (mounted) setState(() { _blockedCount = 0; _blockedElements.clear(); });
          Navigator.pop(context);
        },
        onActivatePicker: _activatePicker,
        onOpenFullPage: _showAdFullPage,
        onRestore: _showRestoreDialog,
      ),
    );
  }

  void _showAdFullPage() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AdBlockFullPage(
        enabled: _adBlockEnabled,
        blockedCount: _blockedCount,
        blockedElements: _blockedElements,
        onToggle: (v) {
          if (mounted) setState(() => _adBlockEnabled = v);
          if (v) _injectJs();
          Navigator.pop(context);
        },
        onReset: () {
          if (mounted) setState(() { _blockedCount = 0; _blockedElements.clear(); });
          Navigator.pop(context);
        },
        onActivatePicker: _activatePicker,
      ),
    );
  }

  Future<void> _reopenInWatchtower() async {
    final url = _url;
    if (url.isNotEmpty) {
      try {
        final all = await isar.mangas.filter().idIsNotNull().findAll();
        Manga? match;
        for (final m in all) {
          final link = m.link ?? '';
          if (link.isNotEmpty && url.contains(link)) {
            match = m;
            break;
          }
        }
        if (match != null && mounted) {
          context.push('/manga-reader/detail', extra: match.id!);
          return;
        }
      } catch (_) {}
    }
    if (mounted) context.pop();
  }

  // ── Video interception helpers ─────────────────────────────────────────────

  /// Returns true if the URL points directly to a playable video/HLS manifest.
  bool _isVideoUrl(String url) {
    if (url.isEmpty) return false;
    final lo = url.toLowerCase().split('?').first.split('#').first;
    for (final ext in const [
      '.m3u8', '.mp4', '.mkv', '.webm', '.mov', '.avi', '.mpd',
    ]) {
      if (lo.endsWith(ext)) return true;
    }
    return false;
  }

  /// Called whenever JS / shouldOverrideUrlLoading / shouldInterceptRequest
  /// detects a media URL. Shows the floating PiP player immediately.
  ///
  /// Dedup: the same base URL (without query string) is only opened once per
  /// page load. The JS layer has its own in-page dedup; this guards against
  /// the JS + shouldInterceptRequest firing for the same stream simultaneously.
  void _handleInterceptedVideo(
    String url, {
    String? title,
    String quality = '',
    String type = '',
  }) {
    if (!mounted || url.isEmpty) return;
    final baseUrl = url.split('?').first.split('#').first;
    if (_interceptedUrls.contains(baseUrl)) return;
    _interceptedUrls.add(baseUrl);
    _lastInterceptTime = DateTime.now();
    _showFloatingPlayer(url, title: title, quality: quality, type: type);
  }

  // ── Floating PiP helpers ─────────────────────────────────────────────────

  /// Shows a draggable floating video player (PiP) on top of the WebView.
  Future<void> _showFloatingPlayer(
    String url, {
    String? title,
    String quality = '',
    String type = '',
  }) async {
    // Pause the site's video element (JS override already prevents origPlay,
    // but belt-and-suspenders for iframes / non-overridden paths).
    try {
      await _webViewController?.evaluateJavascript(
        source: "document.querySelectorAll('video')"
            ".forEach(function(v){try{v.pause();}catch(e){}});",
      );
    } catch (_) {}

    _dismissFloatingPlayer();
    if (!mounted) return;

    final displayTitle =
        (title != null && title.isNotEmpty) ? title : _displayHost(_url);
    final capturedUrl = url;
    final capturedQuality = quality;
    final capturedType = type;
    final capturedTitle = displayTitle;

    // Extract og:image as thumbnail for the PiP box cover
    String? thumbnailUrl;
    try {
      final result = await _webViewController?.evaluateJavascript(
        source: "(function(){"
          "var m=document.querySelector('meta[property=\"og:image\"]');"
          "if(m) return m.content;"
          "var v=document.querySelector('video');"
          "if(v&&v.poster) return v.poster;"
          "return '';"
          "})()",
      );
      if (result is String && result.isNotEmpty) thumbnailUrl = result;
    } catch (_) {}

    _floatingEntry = OverlayEntry(
      builder: (ctx) => _WebFloatingPlayerOverlay(
        videoUrl: capturedUrl,
        title: capturedTitle,
        quality: capturedQuality,
        type: capturedType,
        thumbnailUrl: thumbnailUrl,
        onFullscreen: () {
          _dismissFloatingPlayer();
          _openInMpvFullscreen(capturedUrl, capturedTitle).then((_) {
            if (mounted) {
              _showFloatingPlayer(
                capturedUrl,
                title: capturedTitle,
                quality: capturedQuality,
                type: capturedType,
              );
            }
          });
        },
        onDismiss: _dismissFloatingPlayer,
      ),
    );

    Overlay.of(context, rootOverlay: true).insert(_floatingEntry!);
  }

  /// Removes the floating PiP player overlay.
  void _dismissFloatingPlayer() {
    _floatingEntry?.remove();
    _floatingEntry?.dispose();
    _floatingEntry = null;
  }

  /// Creates a temporary Isar entry and opens our full MPV player as a
  /// fullscreen modal — used when the user taps the ⤢ button in the PiP.
  Future<void> _openInMpvFullscreen(String url, [String? pageTitle]) async {
    if (!mounted) return;
    try {
      final title = (pageTitle != null && pageTitle.isNotEmpty)
          ? pageTitle
          : _displayHost(_url);

      final manga = Manga(
        source: 'webview_intercept',
        author: '',
        artist: '',
        genre: [],
        imageUrl: '',
        lang: 'all',
        link: url,
        name: title,
        status: Status.unknown,
        description: '',
        sourceId: 0,
        isManga: false,
        itemType: ItemType.anime,
      );

      int chapterId = 0;
      await isar.writeTxn(() async {
        final mangaId = await isar.mangas.put(manga);
        manga.id = mangaId;
        final chapter = Chapter(
          mangaId: mangaId,
          name: title,
          url: url,
        );
        chapterId = await isar.chapters.put(chapter);
        chapter.manga.value = manga;
        await chapter.manga.save();
      });

      if (!mounted) return;

      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(
          builder: (_) => AnimePlayerView(episodeId: chapterId),
          fullscreenDialog: true,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Impossible d\'ouvrir dans MPV : $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
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
            dismiss();
            _showAdMenu();
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
    final screenH = MediaQuery.of(context).size.height;

    // Wrap in panel-resize container for Telegram-style minimize
    Widget panelContent = PopScope(
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
          preferredSize: Size.fromHeight(54),
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
              snap: _snap,
              onToggleFooter: () => setState(() => _showFooter = !_showFooter),
              onRefresh: () => _webViewController?.reload(),
              onMinimize: () {
                if (_snap == _PanelSnap.full) {
                  // Animate panel to 0 then push to mini dock (Telegram-style)
                  _minimizeToDock();
                } else {
                  setState(() => _snap = _PanelSnap.full);
                  SystemChrome.setEnabledSystemUIMode(
                      SystemUiMode.immersiveSticky);
                  _animateTo(_snapFraction(_PanelSnap.full));
                }
              },
              onDragStart: _onDragStart,
              onDragUpdate: _onDragUpdate,
              onDragEnd: _onDragEnd,
          ),
        ),
        // ── WebView body ──────────────────────────────────────────────
        body: !kIsWeb && !Platform.isWindows
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
                              // iOS: keep video inline so native fullscreen player doesn't
                              // launch alongside our floating player.
                              allowsInlineMediaPlayback: true,
                              userAgent:
                                  ref.read(userAgentStateProvider) ==
                                          defaultUserAgent
                                      ? null
                                      : ref.read(userAgentStateProvider),
                            ),
                            onWebViewCreated: (c) {
                              _webViewController = c;
                              // Inject video intercept script early (fires before page JS
                              // on Android where onLoadStop can be too late for auto-play).
                              c.addUserScript(userScript: UserScript(
                                source: _kVideoInterceptJs,
                                injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
                                forMainFrameOnly: false,
                              ));
                              c.addJavaScriptHandler(
                                handlerName: 'elementPicked',
                                callback: (args) {
                                  if (!mounted) return;
                                  final info = args.isNotEmpty ? args[0].toString() : '';
                                  _showPickedElementDialog(info);
                                },
                              );
                              c.addJavaScriptHandler(
                                handlerName: 'pickerClosed',
                                callback: (args) {
                                  if (!mounted) return;
                                  setState(() => _pickerMode = false);
                                },
                              );
                              c.addJavaScriptHandler(
                                handlerName: 'videoIntercepted',
                                callback: (args) {
                                  if (!mounted || args.isEmpty) return;
                                  try {
                                    // New format: JSON payload from enhanced JS
                                    final raw = args[0];
                                    final jsonStr = raw is String ? raw : raw.toString();
                                    final data = jsonDecode(jsonStr) as Map<String, dynamic>;
                                    final videoUrl = (data['url'] ?? '').toString().trim();
                                    final pageTitle = (data['title'] ?? '').toString().trim();
                                    final quality = (data['quality'] ?? '').toString().trim();
                                    final type = (data['type'] ?? '').toString().trim();
                                    if (videoUrl.isNotEmpty) {
                                      _handleInterceptedVideo(
                                        videoUrl,
                                        title: pageTitle.isEmpty ? null : pageTitle,
                                        quality: quality,
                                        type: type,
                                      );
                                    }
                                  } catch (_) {
                                    // Fallback: legacy positional args format
                                    final videoUrl = args[0].toString().trim();
                                    final pageTitle = args.length > 1 ? args[1].toString().trim() : null;
                                    if (videoUrl.isNotEmpty) {
                                      _handleInterceptedVideo(videoUrl, title: pageTitle);
                                    }
                                  }
                                },
                              );
                            },
                            onCreateWindow: (c, req) async {
                              return true;
                            },
                            onLoadStart: (c, url) {
                              if (mounted) setState(() {
                                _url = url.toString();
                                _interceptedUrls.clear();
                              });
                            },
                            onLoadStop: (c, url) async {
                              if (mounted) setState(() => _url = url.toString());
                              await _injectJs();
                              try {
                                await c.evaluateJavascript(source: _kVideoInterceptJs);
                              } catch (_) {}
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
                              if (_adBlockEnabled) {
                                final url = action.request.url?.toString() ?? '';
                                if (_isAdUrl(url)) {
                                  if (mounted) setState(() => _blockedCount++);
                                  return NavigationActionPolicy.CANCEL;
                                }
                              }
                              // Intercept direct navigation to a video file → offer MPV
                              if (action.isForMainFrame == true) {
                                final rawUrl = action.request.url?.toString() ?? '';
                                if (_isVideoUrl(rawUrl)) {
                                  _handleInterceptedVideo(rawUrl, title: _title);
                                  return NavigationActionPolicy.CANCEL;
                                }
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
                                    if (_adBlockEnabled && _isAdUrl(url)) {
                                      if (mounted) setState(() => _blockedCount++);
                                      return WebResourceResponse(
                                        contentType: 'text/plain',
                                        statusCode: 200,
                                        reasonPhrase: 'OK',
                                        data: Uint8List(0),
                                      );
                                    }
                                    // Android: intercept video resource requests
                                    // (XHR/fetch interception via JS misses some cases on Android).
                                    if (_isVideoUrl(url)) {
                                      _handleInterceptedVideo(url, title: _title);
                                      // Block the WebView from loading the stream itself
                                      // so only our floating player plays it.
                                      return WebResourceResponse(
                                        contentType: 'text/plain',
                                        statusCode: 200,
                                        reasonPhrase: 'OK',
                                        data: Uint8List(0),
                                      );
                                    }
                                    return null;
                                  }
                                : null,
                          )
            : kIsWeb
                ? _WebViewNotAvailable(url: widget.url)
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
                onReopenInApp: _reopenInWatchtower,
              )
            : null,
      ),
    );

    // ── Telegram-style minimize panel ─────────────────────────────────────────
    return Stack(
      fit: StackFit.expand,
      children: [
        // Dim overlay when minimized — purely visual, no tap-to-dismiss
        if (_currentFraction < 0.99)
          IgnorePointer(
            child: Container(
              color: Colors.black.withValues(alpha: (1.0 - _currentFraction).clamp(0, 0.65)),
            ),
          ),
        // Panel anchored at bottom, sized by _currentFraction
        Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            height: _isClosing
                ? (screenH * _currentFraction).clamp(0.0, screenH)
                : (screenH * _currentFraction).clamp(56.0, screenH),
            child: panelContent,
          ),
        ),
      ],
    );
  }
}

  // ─── Web placeholder widget (Flutter web build) ───────────────────────────────

  class _WebViewNotAvailable extends StatelessWidget {
    final String url;
    const _WebViewNotAvailable({required this.url});

    @override
    Widget build(BuildContext context) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final cs = Theme.of(context).colorScheme;
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.public_off_rounded,
                size: 56,
                color: cs.onSurfaceVariant.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 16),
              Text(
                'WebView non disponible en version web',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Les sites ne peuvent pas être affichés dans l'iframe du navigateur "
                "en raison des politiques X-Frame-Options. Ouvrez le lien directement.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () async {
                  final uri = Uri.tryParse(url);
                  if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Ouvrir dans le navigateur'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

// ─── Browser header (drag handle + address bar + progress) ───────────────────

class _BrowserHeader extends StatefulWidget {
  final String url;
  final String title;
  final double progress;
  final bool isDark;
  final ColorScheme cs;
  final bool adEnabled;
  final int blockedCount;
  final bool showFooter;
  final bool incognito;
  final _PanelSnap snap;
  final VoidCallback onToggleFooter;
  final VoidCallback onRefresh;
  final VoidCallback onMinimize;
  final GestureDragStartCallback onDragStart;
  final GestureDragUpdateCallback onDragUpdate;
  final GestureDragEndCallback onDragEnd;

  const _BrowserHeader({
    super.key,
    required this.url,
    required this.title,
    required this.progress,
    required this.isDark,
    required this.cs,
    required this.adEnabled,
    required this.blockedCount,
    required this.showFooter,
    required this.incognito,
    required this.snap,
    required this.onToggleFooter,
    required this.onRefresh,
    required this.onMinimize,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
  });

  @override
  State<_BrowserHeader> createState() => _BrowserHeaderState();
}

class _BrowserHeaderState extends State<_BrowserHeader>
    with SingleTickerProviderStateMixin {
  late AnimationController _refreshCtrl;
  late Animation<double> _refreshAnim;

  @override
  void initState() {
    super.initState();
    _refreshCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _refreshAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _refreshCtrl, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _refreshCtrl.dispose();
    super.dispose();
  }

  void _onRefreshTap() {
    widget.onRefresh();
    _refreshCtrl.forward(from: 0).then((_) => _refreshCtrl.reset());
  }

  @override
  Widget build(BuildContext context) {
    final secure = _isSecure(widget.url);
    final displayTitle = widget.title.isNotEmpty ? widget.title : _displayHost(widget.url);
    final textColor = widget.isDark ? Colors.white : Colors.black87;
    final subColor = widget.isDark ? Colors.grey.shade500 : Colors.grey.shade500;
    final isMini = widget.snap == _PanelSnap.mini;

    // Left icon colour: incognito=purple, HTTPS=green, HTTP=grey
    final Color shieldColor = widget.incognito
        ? Colors.deepPurple.shade300
        : secure
            ? (widget.isDark ? Colors.greenAccent.shade400 : Colors.green.shade600)
            : subColor;

    return GestureDetector(
      onVerticalDragStart: widget.onDragStart,
      onVerticalDragUpdate: widget.onDragUpdate,
      onVerticalDragEnd: widget.onDragEnd,
      behavior: HitTestBehavior.translucent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle pill (hidden in fullscreen mode) ───────────
          if (widget.snap != _PanelSnap.full)
            Center(
              child: Container(
                width: 36, height: 4,
                margin: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: (widget.isDark ? Colors.white : Colors.black).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            )
          else
            const SizedBox(height: 6),

          // Address bar row — completely flat, no container/pill/box
          SizedBox(
            height: 40,
            child: Row(
              children: [
                // Left: shield (secure) or ghost (incognito) — tap = toggle footer
                GestureDetector(
                  onTap: widget.onToggleFooter,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    child: SvgPicture.asset(
                      widget.incognito ? 'assets/icons/ghost.svg' : 'assets/icons/block-ads.svg',
                      width: 20,
                      height: 20,
                      colorFilter: ColorFilter.mode(shieldColor, BlendMode.srcIn),
                    ),
                  ),
                ),

                // Title — centered, plain text, no box
                Expanded(
                  child: GestureDetector(
                    onLongPress: () {
                      Clipboard.setData(ClipboardData(text: widget.url));
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
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: textColor,
                              overflow: TextOverflow.ellipsis,
                            ),
                            maxLines: 1,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (widget.adEnabled && widget.blockedCount > 0) ...[
                          const SizedBox(width: 6),
                          Text(
                            widget.blockedCount > 99 ? '99+' : '${widget.blockedCount}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: widget.isDark ? Colors.greenAccent.shade400 : Colors.green.shade600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Right: minimize button + refresh
                GestureDetector(
                  onTap: widget.onMinimize,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                    child: Icon(
                      isMini ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      size: 22,
                      color: subColor,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _onRefreshTap,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    child: RotationTransition(
                      turns: _refreshAnim,
                      child: Icon(
                        Icons.refresh_rounded,
                        size: 20,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Progress bar
          SizedBox(
            height: 2,
            child: widget.progress < 1.0
                ? LinearProgressIndicator(
                    value: widget.progress,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(widget.cs.primary),
                  )
                : const SizedBox.shrink(),
          ),

          // Subtle divider
          Divider(
            height: 1,
            thickness: 0.5,
            color: widget.isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ],
      ),
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
  final VoidCallback? onReopenInApp;

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
    this.onReopenInApp,
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
                  // Re-open in Watchtower
                  _ToolbarBtn(
                    icon: Icons.open_in_new_rounded,
                    size: 20,
                    onTap: onReopenInApp,
                    isDark: isDark,
                    overrideColor: isDark
                        ? Colors.deepPurple.shade200
                        : Colors.deepPurple.shade400,
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
  final Color? overrideColor;

  const _ToolbarBtn({
    this.icon,
    this.svgAsset,
    required this.size,
    required this.onTap,
    required this.isDark,
    this.disabledColor,
    this.overrideColor,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = overrideColor ?? (isDark ? Colors.white : Colors.black87);
    final color = onTap == null
        ? (disabledColor ?? (isDark ? Colors.grey.shade700 : Colors.grey.shade400))
        : activeColor;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
      final iconBg = highlight
          ? (accent ?? (isDark ? Colors.greenAccent.shade400 : Colors.green.shade600)).withValues(alpha: 0.12)
          : (isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.05));
      return GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.translucent,
        child: SizedBox(
          width: 62,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: svgAsset != null
                      ? SvgPicture.asset(
                          svgAsset,
                          width: 26,
                          height: 26,
                          colorFilter: ColorFilter.mode(effectiveColor, BlendMode.srcIn),
                        )
                      : Icon(icon, size: 26, color: effectiveColor),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  color: highlight ? effectiveColor : (accent ?? labelColor),
                  fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
                  decoration: TextDecoration.none,
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
            padding: const EdgeInsets.symmetric(vertical: 10),
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
      // Pleine largeur, arrondi uniquement en haut
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.48 : 0.14),
            blurRadius: 32,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),

            // PageView — 3 pages
            SizedBox(
              height: 190,
              child: ScrollConfiguration(
                behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                child: PageView(
                  controller: _pageCtrl,
                  onPageChanged: (i) => setState(() => _page = i),
                  children: [
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: page1),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: page2),
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: page3),
                  ],
                ),
              ),
            ),

            // Dots — cercles uniformes, bien centrés
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  final active = _page == i;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(3),
                      color: active
                          ? (isDark ? Colors.white.withValues(alpha: 0.85) : Colors.black.withValues(alpha: 0.72))
                          : (isDark ? Colors.white.withValues(alpha: 0.22) : Colors.black.withValues(alpha: 0.18)),
                    ),
                  );
                }),
              ),
            ),

            // Boutons Power + Chevron — alignés à droite
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 20, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Power = fermer le WebView
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                      widget.onCloseWebView();
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.power_settings_new_rounded,
                        size: 22,
                        color: isDark ? Colors.white.withValues(alpha: 0.65) : Colors.black.withValues(alpha: 0.50),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Chevron bas = fermer le sheet
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 26,
                        color: isDark ? Colors.white.withValues(alpha: 0.65) : Colors.black.withValues(alpha: 0.50),
                      ),
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

// ─── AdBlock mini sheet (uBlock Origin style) ─────────────────────────────────

class _AdBlockSheet extends StatelessWidget {
  final bool enabled;
  final int blockedCount;
  final List<String> blockedElements;
  final String currentUrl;
  final void Function(bool) onToggle;
  final VoidCallback onReset;
  final VoidCallback? onActivatePicker;
  final VoidCallback? onOpenFullPage;
  final VoidCallback? onRestore;
  final int hiddenCount;

  const _AdBlockSheet({
    required this.enabled,
    required this.blockedCount,
    required this.blockedElements,
    required this.currentUrl,
    required this.onToggle,
    required this.onReset,
    this.onActivatePicker,
    this.onOpenFullPage,
    this.onRestore,
    this.hiddenCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final divColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.07);
    final domain = _displayHost(currentUrl);
    final on = enabled;
    final powerColor = on
        ? (isDark ? Colors.greenAccent.shade400 : Colors.green.shade600)
        : (isDark ? Colors.grey.shade500 : Colors.grey.shade400);
    final ringOuter = on
        ? powerColor.withValues(alpha: 0.12)
        : Colors.grey.withValues(alpha: 0.07);
    final ringInner = on
        ? powerColor.withValues(alpha: 0.22)
        : Colors.grey.withValues(alpha: 0.12);

    return Container(
      margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.13),
            blurRadius: 28,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Drag handle ─────────────────────────────────────────
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(color: divColor, borderRadius: BorderRadius.circular(2)),
          ),

          // ── Header: shield + title + counter + gear ──────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 14, 0),
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/icons/block-ads.svg',
                  width: 22, height: 22,
                  colorFilter: ColorFilter.mode(
                    on ? powerColor : Colors.grey.shade500,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'AdBlock',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: textColor),
                ),
                const SizedBox(width: 8),
                if (blockedCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: powerColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$blockedCount',
                      style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: powerColor,
                      ),
                    ),
                  ),
                const Spacer(),
                // Gear → full settings page
                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    onOpenFullPage?.call();
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: SvgPicture.asset(
                      'assets/icons/settings.svg',
                      width: 20, height: 20,
                      colorFilter: ColorFilter.mode(subColor, BlendMode.srcIn),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // ── Big power button (ring style) ─────────────────────────
          GestureDetector(
            onTap: () => onToggle(!enabled),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer glow ring
                Container(
                  width: 128, height: 128,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: ringOuter),
                ),
                // Mid ring
                Container(
                  width: 104, height: 104,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: ringInner),
                ),
                // Inner button
                Container(
                  width: 82, height: 82,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: bg,
                    border: Border.all(color: powerColor, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: powerColor.withValues(alpha: on ? 0.4 : 0.08),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(Icons.power_settings_new_rounded, size: 38, color: powerColor),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Status line
          Text(
            on ? 'Protection active' : 'Protection désactivée',
            style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w600,
              color: on ? powerColor : Colors.grey.shade500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            domain,
            style: TextStyle(fontSize: 12, color: subColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 24),
          Divider(height: 1, thickness: 0.5, color: divColor),

          // ── Quick actions row ─────────────────────────────────────
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _AdBlockQuickBtn(
                    icon: Icons.pause_circle_outline_rounded,
                    label: 'Pause\nce site',
                    isDark: isDark,
                    textColor: textColor,
                    onTap: () => Navigator.pop(context),
                  ),
                ),
                VerticalDivider(width: 1, thickness: 0.5, color: divColor),
                Expanded(
                  child: _AdBlockQuickBtn(
                    icon: Icons.timer_outlined,
                    label: 'Pause\n30 min',
                    isDark: isDark,
                    textColor: textColor,
                    onTap: () => Navigator.pop(context),
                  ),
                ),
                VerticalDivider(width: 1, thickness: 0.5, color: divColor),
                Expanded(
                  child: _AdBlockQuickBtn(
                    icon: Icons.colorize_rounded,
                    label: 'Sélect.\nélém.',
                    isDark: isDark,
                    textColor: textColor,
                    accent: Colors.orange,
                    onTap: () {
                      Navigator.pop(context);
                      onActivatePicker?.call();
                    },
                  ),
                ),
                VerticalDivider(width: 1, thickness: 0.5, color: divColor),
                Expanded(
                  child: _AdBlockQuickBtn(
                    icon: Icons.history_rounded,
                    label: 'Restaurer\n${hiddenCount > 0 ? "($hiddenCount)" : "élém."}',
                    isDark: isDark,
                    textColor: textColor,
                    accent: hiddenCount > 0 ? Colors.green.shade400 : null,
                    onTap: () {
                      Navigator.pop(context);
                      onRestore?.call();
                    },
                  ),
                ),
                VerticalDivider(width: 1, thickness: 0.5, color: divColor),
                Expanded(
                  child: _AdBlockQuickBtn(
                    icon: Icons.refresh_rounded,
                    label: 'Remise\nà zéro',
                    isDark: isDark,
                    textColor: textColor,
                    accent: Colors.red.shade400,
                    onTap: onReset,
                  ),
                ),
              ],
            ),
          ),

          Divider(height: 1, thickness: 0.5, color: divColor),

          // ── Stats row ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _AdBlockStat(
                  value: '$blockedCount',
                  label: 'Requêtes\nbloquées',
                  color: isDark ? Colors.greenAccent.shade400 : Colors.green.shade700,
                ),
                Container(width: 1, height: 34, color: divColor),
                _AdBlockStat(
                  value: '${blockedElements.length}',
                  label: 'Éléments\nmasqués',
                  color: isDark ? Colors.orangeAccent : Colors.orange.shade700,
                ),
                Container(width: 1, height: 34, color: divColor),
                _AdBlockStat(
                  value: '1561',
                  label: 'Règles\nactives',
                  color: isDark ? Colors.blueAccent.shade100 : Colors.blue.shade700,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── AdBlock quick action button ─────────────────────────────────────────────

class _AdBlockQuickBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final Color textColor;
  final Color? accent;
  final VoidCallback onTap;

  const _AdBlockQuickBtn({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.textColor,
    required this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? textColor.withValues(alpha: 0.75);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: color),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── AdBlock stat widget ──────────────────────────────────────────────────────

class _AdBlockStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _AdBlockStat({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w800, color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.7)),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ─── AdBlock full settings page ───────────────────────────────────────────────

class _AdBlockFullPage extends StatelessWidget {
  final bool enabled;
  final int blockedCount;
  final List<String> blockedElements;
  final void Function(bool) onToggle;
  final VoidCallback onReset;
  final VoidCallback? onActivatePicker;

  const _AdBlockFullPage({
    required this.enabled,
    required this.blockedCount,
    required this.blockedElements,
    required this.onToggle,
    required this.onReset,
    this.onActivatePicker,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    final divColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.07);

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.14),
              blurRadius: 28, offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Handle
            Container(
              width: 36, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: divColor, borderRadius: BorderRadius.circular(2)),
            ),
            // Title row
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 14),
              child: Row(
                children: [
                  SvgPicture.asset(
                    'assets/icons/block-ads.svg',
                    width: 24, height: 24,
                    colorFilter: ColorFilter.mode(
                      enabled ? (isDark ? Colors.greenAccent.shade400 : Colors.green.shade600) : Colors.grey,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'AdBlock – Paramètres',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: subColor),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: divColor),

            Expanded(
              child: ListView(
                controller: scrollCtrl,
                children: [
                  // Enable toggle
                  SwitchListTile(
                    title: Text("Activer l'AdBlock", style: TextStyle(color: textColor)),
                    subtitle: Text(
                      "Bloque les domaines publicitaires et injecte un filtre CSS/DOM",
                      style: TextStyle(fontSize: 12, color: subColor),
                    ),
                    value: enabled,
                    onChanged: (v) { onToggle(v); Navigator.pop(context); },
                    activeColor: isDark ? Colors.greenAccent : Colors.green.shade600,
                  ),
                  Divider(height: 1, color: divColor),

                  // Stats cards
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                    child: Text('Statistiques', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: subColor)),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    child: Row(
                      children: [
                        Expanded(child: _AdBlockStatCard(value: '$blockedCount', label: 'Requêtes\nbloquées', icon: Icons.block_rounded, color: Colors.green, isDark: isDark)),
                        const SizedBox(width: 8),
                        Expanded(child: _AdBlockStatCard(value: '${blockedElements.length}', label: 'Éléments\nmasqués', icon: Icons.visibility_off_rounded, color: Colors.orange, isDark: isDark)),
                        const SizedBox(width: 8),
                        Expanded(child: _AdBlockStatCard(value: '1561', label: 'Règles\nactives', icon: Icons.rule_rounded, color: Colors.blue, isDark: isDark)),
                      ],
                    ),
                  ),

                  Divider(height: 1, color: divColor),

                  // Tools section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                    child: Text('Outils', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: subColor)),
                  ),
                  ListTile(
                    leading: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.colorize_rounded, size: 20, color: Colors.orange),
                    ),
                    title: Text('Sélectionner des éléments', style: TextStyle(color: textColor, fontSize: 14)),
                    subtitle: Text('Toolbar flottante · touch picker', style: TextStyle(fontSize: 11, color: subColor)),
                    trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: subColor),
                    onTap: onActivatePicker != null
                        ? () { Navigator.pop(context); onActivatePicker!(); }
                        : null,
                  ),
                  ListTile(
                    leading: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.refresh_rounded, size: 20, color: Colors.red.shade400),
                    ),
                    title: Text('Réinitialiser les règles', style: TextStyle(color: textColor, fontSize: 14)),
                    subtitle: Text('Remet le compteur à 0 et efface les règles personnalisées', style: TextStyle(fontSize: 11, color: subColor)),
                    trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: subColor),
                    onTap: () { onReset(); Navigator.pop(context); },
                  ),

                  Divider(height: 1, color: divColor),

                  // Whitelist (placeholder)
                  ListTile(
                    leading: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                      child: Icon(Icons.playlist_remove_rounded, size: 20, color: Colors.blue.shade400),
                    ),
                    title: Text('Liste blanche', style: TextStyle(color: textColor, fontSize: 14)),
                    subtitle: Text('Sites exemptés du filtrage', style: TextStyle(fontSize: 11, color: subColor)),
                    trailing: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: subColor),
                    onTap: () {},
                  ),

                  // Blocked elements list
                  if (blockedElements.isNotEmpty) ...[
                    Divider(height: 1, color: divColor),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                      child: Text(
                        'Éléments bloqués manuellement (${blockedElements.length})',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: subColor),
                      ),
                    ),
                    ...blockedElements.take(20).map((el) => ListTile(
                      dense: true,
                      leading: Icon(Icons.visibility_off_outlined, size: 16, color: Colors.red.shade400),
                      title: Text(
                        el.length > 60 ? '${el.substring(0, 57)}…' : el,
                        style: TextStyle(fontSize: 11, color: textColor, fontFamily: 'monospace'),
                      ),
                    )),
                    if (blockedElements.length > 20)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text('+${blockedElements.length - 20} éléments…', style: TextStyle(fontSize: 11, color: subColor)),
                      ),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── AdBlock stat card (used in full page) ────────────────────────────────────

class _AdBlockStatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  final bool isDark;

  const _AdBlockStatCard({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.14 : 0.09),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.7)),
            textAlign: TextAlign.center,
          ),
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

// ─── Floating PiP video player overlay ────────────────────────────────────────
//
// Appears as a draggable floating window on top of the WebView.
// • Drag anywhere on screen.
// • Drag to left/right edge → snaps and collapses to a small coloured square
//   with a chevron arrow; tap the square to restore.
// • Tap ⤢ → opens our full MPV player (AnimePlayerView) as a modal.
// • Tap × → dismiss.

// ─── Floating PiP player overlay (v4) ────────────────────────────────────────
//
// • 3 vertical snap positions : top / middle / bottom
// • Mini-corner ONLY when >50% of the box crosses the left or right border
// • X and ⤢ buttons are outside the drag GestureDetector area → always tappable
// • Fullscreen → reopens PiP on back-press (handled by caller via .then())
// • Cover thumbnail shown while video loads

class _WebFloatingPlayerOverlay extends StatefulWidget {
  final String videoUrl;
  final String title;
  final String quality;
  final String type;
  final String? thumbnailUrl;
  final VoidCallback onFullscreen;
  final VoidCallback onDismiss;

  const _WebFloatingPlayerOverlay({
    required this.videoUrl,
    required this.title,
    this.quality = '',
    this.type = '',
    this.thumbnailUrl,
    required this.onFullscreen,
    required this.onDismiss,
  });

  @override
  State<_WebFloatingPlayerOverlay> createState() =>
      _WebFloatingPlayerOverlayState();
}

class _WebFloatingPlayerOverlayState extends State<_WebFloatingPlayerOverlay>
    with SingleTickerProviderStateMixin {
  late final Player _player;
  late final VideoController _controller;

  // Absolute drag deltas from the default anchor (bottom-centre)
  double _dx = 0;
  double _dy = 0;

  // Pinch-to-resize
  double _scale = 1.0;
  double _scaleBase = 1.0;

  // Mini (edge-snapped) state
  bool _isMini = false;
  bool _miniLeft = true;
  double _miniTopFrac = 0.55;

  // Snap animation
  late final AnimationController _springCtrl;

  static const double _kMarginH = 10.0;
  static const double _kMarginB = 36.0;
  static const double _kCorner = 18.0;
  static const double _kMiniW = 60.0;
  static const double _kMiniH = 80.0;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _player.open(Media(widget.videoUrl));
    _springCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
  }

  @override
  void dispose() {
    _springCtrl.dispose();
    _player.dispose();
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  double _boxW(double screenW) {
    final baseW = screenW - 2 * _kMarginH;
    return (baseW * _scale).clamp(180.0, screenW);
  }

  double _boxH(double screenW) => _boxW(screenW) * 9.0 / 16.0;

  /// Default anchor: bottom-centre of screen.
  double _anchorLeft(double sw) {
    final bw = _boxW(sw);
    return _kMarginH + (sw - 2 * _kMarginH - bw) / 2;
  }

  double _anchorTop(double sw, double sh) => sh - _kMarginB - _boxH(sw);

  // ── Gestures ───────────────────────────────────────────────────────────────

  void _onScaleStart(ScaleStartDetails d) {
    _springCtrl.stop();
    _scaleBase = _scale;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    setState(() {
      if (d.pointerCount > 1) {
        _scale = (_scaleBase * d.scale).clamp(0.38, 1.62);
      } else {
        _dx += d.focalPointDelta.dx;
        _dy += d.focalPointDelta.dy;
      }
    });
  }

  void _onScaleEnd(ScaleEndDetails d, Size screen) {
    final sw = screen.width;
    final sh = screen.height;
    final bw = _boxW(sw);
    final bh = _boxH(sw);
    final aL = _anchorLeft(sw);
    final aT = _anchorTop(sw, sh);

    final curLeft = aL + _dx;
    final curTop = aT + _dy;
    final vx = d.velocity.pixelsPerSecond.dx;

    // Mini only when >50% of box has crossed the left or right border
    final tooFarLeft = curLeft + bw * 0.5 < 0;
    final tooFarRight = curLeft + bw * 0.5 > sw;
    final fastLeft = vx < -1500 && curLeft < 0;
    final fastRight = vx > 1500 && curLeft + bw > sw;

    if (tooFarLeft || fastLeft) {
      _goMini(left: true, currentTop: curTop, screen: screen);
      return;
    }
    if (tooFarRight || fastRight) {
      _goMini(left: false, currentTop: curTop, screen: screen);
      return;
    }

    // Snap to nearest of 3 vertical positions (top / middle / bottom)
    final topPos = 60.0;
    final midPos = (sh - bh) / 2;
    final botPos = sh - _kMarginB - bh;

    final nearest = [topPos, midPos, botPos].reduce(
      (a, b) => (a - curTop).abs() < (b - curTop).abs() ? a : b,
    );

    _animateDy(nearest - aT);
  }

  void _animateDy(double targetDy) {
    final startDy = _dy;
    final anim = Tween<double>(begin: startDy, end: targetDy).animate(
      CurvedAnimation(parent: _springCtrl, curve: Curves.easeOutCubic),
    );
    anim.addListener(() {
      if (mounted) setState(() => _dy = anim.value);
    });
    _springCtrl.forward(from: 0);
  }

  void _goMini({
    required bool left,
    required double currentTop,
    required Size screen,
  }) {
    setState(() {
      _isMini = true;
      _miniLeft = left;
      _miniTopFrac = (currentTop / screen.height).clamp(0.10, 0.82);
      _dx = 0;
      _dy = 0;
    });
  }

  // ── Mini bubble ────────────────────────────────────────────────────────────

  Widget _buildMini(Size screen) {
    final miniTop = screen.height * _miniTopFrac;
    final dx = _miniLeft ? -_kMiniW * 0.40 : screen.width - _kMiniW * 0.60;
    return Positioned(
      left: dx,
      top: miniTop,
      child: GestureDetector(
        onTap: () => setState(() {
          _isMini = false;
          _dx = 0;
          _dy = 0;
        }),
        onPanUpdate: (d) => setState(() {
          _miniTopFrac =
              ((_miniTopFrac * screen.height + d.delta.dy) / screen.height)
                  .clamp(0.08, 0.84);
        }),
        child: Container(
          width: _kMiniW,
          height: _kMiniH,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.60),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(fit: StackFit.expand, children: [
              // Cover thumbnail
              if (widget.thumbnailUrl != null)
                Image.network(
                  widget.thumbnailUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              // Live video on top
              Video(controller: _controller, controls: NoVideoControls),
              // Overlay tint + chevron
              Container(color: Colors.black.withValues(alpha: 0.28)),
              Center(
                child: Icon(
                  _miniLeft
                      ? Icons.chevron_right_rounded
                      : Icons.chevron_left_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ── Full PiP player ────────────────────────────────────────────────────────

  Widget _buildFull(Size screen) {
    final sw = screen.width;
    final sh = screen.height;
    final bw = _boxW(sw);
    final bh = _boxH(sw);
    final aL = _anchorLeft(sw);
    final aT = _anchorTop(sw, sh);

    final left = (aL + _dx).clamp(0.0, sw - bw);
    final top = (aT + _dy).clamp(60.0, sh - bh - 12.0);

    return Positioned(
      left: left,
      top: top,
      width: bw,
      height: bh,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // ── Video layer (IgnorePointer so gestures pass to drag detector) ──
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(_kCorner),
              child: Stack(fit: StackFit.expand, children: [
                // Cover thumbnail shown while video loads
                if (widget.thumbnailUrl != null)
                  Image.network(
                    widget.thumbnailUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                // Live video
                Video(controller: _controller, controls: NoVideoControls),
              ]),
            ),
          ),

          // ── Drag / pinch area — covers middle zone only (avoids buttons & seek) ──
          Positioned(
            top: 52,
            left: 0,
            right: 0,
            bottom: 30,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onScaleStart: _onScaleStart,
              onScaleUpdate: _onScaleUpdate,
              onScaleEnd: (d) => _onScaleEnd(d, screen),
              onTap: () => _player.state.playing
                  ? _player.pause()
                  : _player.play(),
            ),
          ),

          // ── Buffering indicator ────────────────────────────────────────
          StreamBuilder<bool>(
            stream: _player.stream.buffering,
            builder: (_, snap) {
              if (snap.data != true) return const SizedBox.shrink();
              return IgnorePointer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_kCorner),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.45),
                    child: const Center(
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    ),
                  ),
                ),
              );
            },
          ),

          // ── X close — top-left (ABOVE drag detector) ───────────────────
          Positioned(
            top: 8,
            left: 8,
            child: _PipBtn(icon: Icons.close_rounded, onTap: widget.onDismiss),
          ),

          // ── Fullscreen — top-right (ABOVE drag detector) ───────────────
          Positioned(
            top: 8,
            right: 8,
            child: _PipBtn(
                icon: Icons.fullscreen_rounded, onTap: widget.onFullscreen),
          ),

          // ── Seek bar — bottom ──────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(18)),
              child: _PipSeekBar(player: _player),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screen = MediaQuery.of(context).size;
    return _isMini ? _buildMini(screen) : _buildFull(screen);
  }
}

// ─── PiP seek bar (interactive) ───────────────────────────────────────────────

class _PipSeekBar extends StatelessWidget {
  final Player player;
  const _PipSeekBar({required this.player});

  void _seekFromX(BuildContext ctx, double localX, int durMs) {
    if (durMs <= 0) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return;
    final frac = (localX / box.size.width).clamp(0.0, 1.0);
    player.seek(Duration(milliseconds: (frac * durMs).round()));
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration>(
      stream: player.stream.position,
      builder: (_, posSnap) => StreamBuilder<Duration>(
        stream: player.stream.duration,
        builder: (ctx, durSnap) {
          final posMs = posSnap.data?.inMilliseconds ?? 0;
          final durMs = durSnap.data?.inMilliseconds ?? 0;
          final progress =
              durMs > 0 ? (posMs / durMs).clamp(0.0, 1.0) : 0.0;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (d) =>
                _seekFromX(ctx, d.localPosition.dx, durMs),
            onTapUp: (d) => _seekFromX(ctx, d.localPosition.dx, durMs),
            child: SizedBox(
              height: 28,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 3,
                  child: Stack(children: [
                    // Track background
                    Container(color: Colors.white.withValues(alpha: 0.28)),
                    // Playback progress
                    FractionallySizedBox(
                      widthFactor: progress,
                      child: Container(color: Colors.white),
                    ),
                  ]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─── PiP control button (blurred circle, Safari-style) ────────────────────────

class _PipBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _PipBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.52),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}
