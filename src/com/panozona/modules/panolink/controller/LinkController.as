﻿/*
Copyright 2012 Marek Standio.

This file is part of SaladoPlayer.

SaladoPlayer is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published
by the Free Software Foundation, either version 3 of the License,
or (at your option) any later version.

SaladoPlayer is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty
of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with SaladoPlayer. If not, see <http://www.gnu.org/licenses/>.
*/
package com.panozona.modules.panolink.controller{
	
	import com.panozona.modules.panolink.events.WindowEvent;
	import com.panozona.modules.panolink.view.LinkView;
	import com.panozona.player.module.data.property.Size;
	import com.panozona.player.module.Module;
	import flash.display.BitmapData;
	import flash.display.Loader;
	import flash.display.LoaderInfo;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.external.ExternalInterface;
	import flash.geom.Point;
	import flash.geom.Rectangle;
	import flash.net.URLRequest;
	import flash.system.ApplicationDomain;
	
	public class LinkController{
		
		private var paramsFirstClone:Object;
		private var currentLink:String;
		
		private var _linkView:LinkView;
		private var _module:Module;
		
		public function LinkController(linkView:LinkView, module:Module){
			
			_linkView = linkView;
			_module = module;
			
			var recognizedValues:Object = recognizeURL(ExternalInterface.call("window.location.href.toString"));
			if (recognizedValues != null){
				var panoDataReference:Object = _module.saladoPlayer.managerData.getPanoramaDataById(recognizedValues.id);
				if (panoDataReference == null) {
					_module.printWarning("Panorama does not exist: " + recognizedValues.id);
				}else {
					var paramsReference:Object = panoDataReference.params;
					stashOriginalParams(recognizedValues.id);
					_module.saladoPlayer.managerData.allPanoramasData.firstPanorama = recognizedValues.id;
					if (!isNaN(recognizedValues.pan)) {
						paramsReference.pan = recognizedValues.pan;
					}
					if (!isNaN(recognizedValues.tilt)) {
						paramsReference.tilt = recognizedValues.tilt;
					}
					if (!isNaN(recognizedValues.fov)) {
						paramsReference.fov = recognizedValues.fov;
					}
				}
			}
			var panoramaEventClass:Class = ApplicationDomain.currentDomain.getDefinition("com.panozona.player.manager.events.PanoramaEvent") as Class;
			_module.saladoPlayer.manager.addEventListener(panoramaEventClass.PANORAMA_LOADED, onPanoramaLoaded, false, 0, true);
			
			_linkView.panoLinkData.windowData.addEventListener(WindowEvent.CHANGED_OPEN, onOpenChange, false, 0, true);
			
			var imageLoader:Loader = new Loader();
			imageLoader.contentLoaderInfo.addEventListener(IOErrorEvent.IO_ERROR, imageLost, false, 0, true);
			imageLoader.contentLoaderInfo.addEventListener(Event.COMPLETE, imageLoaded, false, 0, true);
			imageLoader.load(new URLRequest(_linkView.panoLinkData.settings.path));
		}
		
		private function imageLost(error:IOErrorEvent):void {
			error.target.removeEventListener(IOErrorEvent.IO_ERROR, imageLost);
			error.target.removeEventListener(Event.COMPLETE, imageLoaded);
			_module.printError(error.text);
		}
		
		private function imageLoaded(e:Event):void {
			e.target.removeEventListener(IOErrorEvent.IO_ERROR, imageLost);
			e.target.removeEventListener(Event.COMPLETE, imageLoaded);
			
			var bitmapData:BitmapData = new BitmapData((e.target as LoaderInfo).width, (e.target as LoaderInfo).height, true, 0);
			bitmapData.draw((e.target as LoaderInfo).content);
			
			var butWidth:Number = bitmapData.width;
			var butHeight:Number = Math.ceil((bitmapData.height - 1) / 2);
			var bitmapDataPlain:BitmapData = new BitmapData(butWidth, butHeight, true, 0);
			bitmapDataPlain.copyPixels(bitmapData, new Rectangle(0, 0, butWidth, butHeight), new Point(0, 0), null, null, true);
			var bitmapDataActive:BitmapData = new BitmapData(butWidth, butHeight, true, 0);
			bitmapDataActive.copyPixels(bitmapData, new Rectangle(0, butHeight + 1, butWidth, butHeight), new Point(0, 0), null, null, true);
			
			_linkView.setBitmapsData(bitmapDataPlain, bitmapDataActive);
			
			_linkView.panoLinkData.windowData.addEventListener(WindowEvent.CHANGED_CURRENT_SIZE, handleWindowSizeChange, false, 0, true);
			
			var maxSize:Size = new Size(_linkView.panoLinkData.settings.maxLength, _linkView.height);
			var minSize:Size = new Size(_linkView.panoLinkData.settings.minLength, _linkView.height);
			
			_linkView.panoLinkData.linkData.setMinMaxSize(minSize, maxSize);
		}
		
		private function handleWindowSizeChange(event:Event = null):void {
			_linkView.draw();
			onEnterFrame();
		}
		
		private function onPanoramaLoaded(loadPanoramaEvent:Object):void {
			var panoramaEventClass:Class = ApplicationDomain.currentDomain.getDefinition("com.panozona.player.manager.events.PanoramaEvent") as Class;
			_module.saladoPlayer.manager.removeEventListener(panoramaEventClass.PANORAMA_LOADED, onPanoramaLoaded);
			onOpenChange();
			setOriginalParams();
		}
		
		private function onOpenChange(WindowEvent:Object = null):void {
			if (_linkView.panoLinkData.windowData.open){
				_linkView.stage.addEventListener(Event.ENTER_FRAME, onEnterFrame, false, 0, true);
			}else {
				_linkView.stage.removeEventListener(Event.ENTER_FRAME, onEnterFrame);
			}
		}
		
		private function onEnterFrame(e:Event = null):void {
			var newLink:String = getUrlLink(ExternalInterface.call("window.location.href.toString"));
			if (newLink != currentLink) {
				_linkView.setText(newLink);
				currentLink = newLink;
			}
		}
		
		public function getUrlLink(url:String):String {
			var result:String = "";
			if (url.indexOf("?") > 0) {
				result += url.substr(0, url.indexOf("?") + 1);
				var params:Array = url.substring(url.indexOf("?") + 1, url.length).split("&");
				for each(var param:String in params) {
					if (!param.match(/^pano=.+/) && !param.match(/^view=.+/)) {
						result += param +"&";
					}
				}
			}else {
				result = url;
				result += "?";
			}
			result += "pano=" + _module.saladoPlayer.manager.currentPanoramaData.id;
			result += "&view=";
			result += Math.floor(_module.saladoPlayer.manager.pan as Number) + ",";
			result += Math.floor(_module.saladoPlayer.manager.tilt as Number) + ",";
			result += Math.floor(_module.saladoPlayer.manager.fieldOfView as Number);
			return result;
		}
		
		private function recognizeURL(url:String):Object {
			var id:String;
			var pan:Number;
			var tilt:Number;
			var fov:Number;
			if (url.indexOf("?") > 0) {
				url = url.slice(url.indexOf("?")+1, url.length);
				var params:Array = url.split("&");
				for each(var param:String in params) {
					var temp:Array = param.split("=");
					if(temp.length != 2) continue;
					if(temp[0] == "pano"){
						id = (temp[1]);
					}else if (temp[0] == "view") {
						
						var values:Array = temp[1].split(",");
						try{
							pan = Number(values[0]);
							tilt = Number(values[1]);
							fov = Number(values[2]);
						}catch (e:Error){
							_module.printWarning("Invalid view values: " + temp[1]);
						}
					}
				}
			}
			if (id != null){
				var result:Object = new Object();
				result.id = id;
				result.pan = pan;
				result.tilt = tilt;
				result.fov = fov;
				return result;
			}
			return null;
		}
		
		private function stashOriginalParams(panoramaId:String):void {
			var panoramaData:Object = _module.saladoPlayer.managerData.getPanoramaDataById(panoramaId);
			if (panoramaData == null) return;
			paramsFirstClone = panoramaData.params.clone();
		}
		
		private function setOriginalParams():void {
			if (_module.saladoPlayer.managerData.allPanoramasData.firstPanorama == null) return;
			var paramsReference:Object = _module.saladoPlayer.managerData.getPanoramaDataById(
				_module.saladoPlayer.managerData.allPanoramasData.firstPanorama).params;
			if (paramsReference != null && paramsFirstClone != null) {
				paramsReference.pan = paramsFirstClone.pan;
				paramsReference.tilt = paramsFirstClone.tilt;
				paramsReference.fov = paramsFirstClone.fov;
			}
		}
	}
}
