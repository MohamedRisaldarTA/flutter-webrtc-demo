import 'package:flutter/material.dart';
import 'dart:core';
import 'signaling.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class CallSample extends StatefulWidget {
  static String tag = 'call_sample';

  final String host;


  CallSample({Key key, @required this.host}) : super(key: key);

  @override
  _CallSampleState createState() => _CallSampleState();
}

class _CallSampleState extends State<CallSample> {
  Signaling _signaling;
  List<dynamic> _peers;
  var _selfId;
  var renders = <RTCVideoRenderer>[];
  bool _inCalling = false;
  Session _session;
  final int cameraCount = 31;
  // ignore: unused_element
  _CallSampleState({Key key});

  @override
  initState() {
    super.initState();
    initRenderers();
    _connect();
  }

  initRenderers() async {
    for (var i = 0; i < cameraCount; i++) {
      try {
        print('initialized - ${i - 1}');
        var renderer = RTCVideoRenderer();
        await renderer.initialize();
        renders.add(renderer);
      } catch (e) {
        print('exception -$e - $i');
        break;
      }
    }
  }

  @override
  deactivate() {
    super.deactivate();
    if (_signaling != null) _signaling.close();
    for (var i in renders) {
      try {
       i.dispose();

      } catch (e) {
        print('exception -$e - $i');
        break;
      }
    }
  }

  void _connect() async {
    if (_signaling == null) {
      _signaling = Signaling(widget.host)..connect();

      _signaling.onSignalingStateChange = (SignalingState state) {
        switch (state) {
          case SignalingState.ConnectionClosed:
          case SignalingState.ConnectionError:
          case SignalingState.ConnectionOpen:
            break;
        }
      };

      _signaling.onCallStateChange = (Session session, CallState state) {
        switch (state) {
          case CallState.CallStateNew:
            setState(() {
              _session = session;
              _inCalling = true;
            });
            break;
          case CallState.CallStateBye:
            setState(() {
              for(var item in renders){
                item.srcObject = null;
              }
              _inCalling = false;
              _session = null;
            });
            break;
          case CallState.CallStateInvite:
          case CallState.CallStateConnected:
          case CallState.CallStateRinging:
        }
      };

      _signaling.onPeersUpdate = ((event) {
        setState(() {
          _selfId = event['self'];
          _peers = event['peers'];
        });
      });

      _signaling.onLocalStream = ((_, stream) {
        for(var render in renders){
          render.srcObject = stream;
        }
      });

      _signaling.onAddRemoteStream = ((_, stream) {
      });

      _signaling.onRemoveRemoteStream = ((_, stream) {
      });
    }
  }

  _invitePeer(BuildContext context, String peerId, bool useScreen) async {
    if (_signaling != null && peerId != _selfId) {
      _signaling.invite(peerId, 'video', useScreen);
    }
  }

  _hangUp() {
    if (_signaling != null) {
      _signaling.bye(_session.sid);
    }
  }

  _switchCamera() {
    _signaling.switchCamera();
  }

  _muteMic() {
    _signaling.muteMic();
  }

  _buildRow(context, peer) {
    var self = (peer['id'] == _selfId);
    return ListBody(children: <Widget>[
      ListTile(
        title: Text(self
            ? peer['name'] + '[Your self]'
            : peer['name'] + '[' + peer['user_agent'] + ']'),
        onTap: null,
        trailing: SizedBox(
            width: 100.0,
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  IconButton(
                    icon: const Icon(Icons.videocam),
                    onPressed: () => _invitePeer(context, peer['id'], false),
                    tooltip: 'Video calling',
                  ),
                  IconButton(
                    icon: const Icon(Icons.screen_share),
                    onPressed: () => _invitePeer(context, peer['id'], true),
                    tooltip: 'Screen sharing',
                  )
                ])),
        subtitle: Text('id: ' + peer['id']),
      ),
      Divider()
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('P2P Call Sample'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: null,
            tooltip: 'setup',
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _inCalling
          ? SizedBox(
              width: 200.0,
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    FloatingActionButton(
                      child: const Icon(Icons.switch_camera),
                      onPressed: _switchCamera,
                    ),
                    FloatingActionButton(
                      onPressed: _hangUp,
                      tooltip: 'Hangup',
                      child: Icon(Icons.call_end),
                      backgroundColor: Colors.pink,
                    ),
                    FloatingActionButton(
                      child: const Icon(Icons.mic_off),
                      onPressed: _muteMic,
                    )
                  ]))
          : null,
      body: _inCalling
          ? GridView.count(shrinkWrap: true,
        crossAxisCount: 6,
        children: [
          // RTCVideoView(_remoteRenderer),RTCVideoView(_localRenderer),
          for (var i=0;i<renders.length;i++) Stack(children: [RTCVideoView(renders[i]),Center(child: Text('$i'))])
        ],
      )
          : ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.all(0.0),
              itemCount: (_peers != null ? _peers.length : 0),
              itemBuilder: (context, i) {
                return _buildRow(context, _peers[i]);
              }),
    );
  }
}
