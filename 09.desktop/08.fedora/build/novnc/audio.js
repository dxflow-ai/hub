const ENABLE = false;
const CHANNELS = 1;
const RATE = 22050;

class PCMPlayer {
    constructor() {
        this.init();
    }

    init() {
        this.option = {
            inputCodec: "Int16",
            channels: CHANNELS,
            rate: RATE,
            flushTime: 500,
            fftSize: 2048,
        };

        this.samples = new Float32Array();
        this.convertValue = 32768;
        this.typedArray = Int16Array;

        this.interval = setInterval(this.flush.bind(this), this.option.flushTime);

        this.initAudioContext();
        this.bindAudioContextEvent();
    }

    initAudioContext() {
        this.audioCtx = new (window.AudioContext || window.webkitAudioContext)();

        this.gainNode = this.audioCtx.createGain();
        this.gainNode.gain.value = 0.1;
        this.gainNode.connect(this.audioCtx.destination);

        this.startTime = this.audioCtx.currentTime;

        this.analyserNode = this.audioCtx.createAnalyser();
        this.analyserNode.fftSize = this.option.fftSize;
    }

    feed(data) {
        const isTypedArray =
            (data.byteLength && data.buffer && data.buffer.constructor == ArrayBuffer) ||
            data.constructor == ArrayBuffer;

        if (!isTypedArray) {
            return;
        }

        data = this.getFormattedValue(data);

        const tmp = new Float32Array(this.samples.length + data.length);

        tmp.set(this.samples, 0);
        tmp.set(data, this.samples.length);

        this.samples = tmp;
    }

    getFormattedValue(data) {
        if (data.constructor == ArrayBuffer) {
            data = new this.typedArray(data);
        } else {
            data = new this.typedArray(data.buffer);
        }

        let float32 = new Float32Array(data.length);

        for (let i = 0; i < data.length; i++) {
            float32[i] = data[i] / this.convertValue;
        }

        return float32;
    }

    volume(volume) {
        this.gainNode.gain.value = volume;
    }

    destroy() {
        if (this.interval) {
            clearInterval(this.interval);
        }

        this.samples = null;

        this.audioCtx.close();
        this.audioCtx = null;
    }

    flush() {
        if (!this.samples.length) {
            return;
        }

        const self = this;
        var bufferSource = this.audioCtx.createBufferSource();
        if (typeof this.option.onended === "function") {
            bufferSource.onended = function (event) {
                self.option.onended(this, event);
            };
        }

        const length = this.samples.length / this.option.channels;
        const audioBuffer = this.audioCtx.createBuffer(this.option.channels, length, this.option.rate);

        for (let channel = 0; channel < this.option.channels; channel++) {
            const audioData = audioBuffer.getChannelData(channel);
            let offset = channel;
            let decrement = 50;
            for (let i = 0; i < length; i++) {
                audioData[i] = this.samples[offset];
                if (i < 50) {
                    audioData[i] = (audioData[i] * i) / 50;
                }
                if (i >= length - 51) {
                    audioData[i] = (audioData[i] * decrement--) / 50;
                }
                offset += this.option.channels;
            }
        }

        if (this.startTime < this.audioCtx.currentTime) {
            this.startTime = this.audioCtx.currentTime;
        }

        bufferSource.buffer = audioBuffer;
        bufferSource.connect(this.gainNode);
        bufferSource.connect(this.analyserNode);
        bufferSource.start(this.startTime);

        this.startTime += audioBuffer.duration;
        this.samples = new Float32Array();
    }

    async pause() {
        await this.audioCtx.suspend();
    }

    async continue() {
        await this.audioCtx.resume();
    }

    bindAudioContextEvent() {
        const self = this;
        if (typeof self.option.onstatechange === "function") {
            this.audioCtx.onstatechange = function (event) {
                self.audioCtx && self.option.onstatechange(this, event, self.audioCtx.state);
            };
        }
    }
}

class AudioWebSocket {
    reconnect = true;

    constructor(url, listeners) {
        this.url = url;
        this.listeners = listeners;

        this.connect();
    }

    connect(reconnectAfter = 3000) {
        const reconnect = () => {
            clearTimeout(this.timout);
            this.timout = setTimeout(() => {
                this.connect(reconnectAfter + 3000);
            }, reconnectAfter);
        };

        try {
            this.source = new WebSocket(this.url);
            this.source.binaryType = "arraybuffer";

            this.source.addEventListener(
                "open",
                () => {
                    reconnectAfter = 4000;
                    this.reconnect = true;

                    clearTimeout(this.timout);

                    if (this.listeners.onOpen) {
                        this.listeners.onOpen();
                    }
                },
                {
                    once: true,
                },
            );

            this.source.addEventListener("message", ({ data }) => {
                if (this.listeners.onMessage) {
                    this.listeners.onMessage(data);
                }
            });

            this.source.addEventListener("error", () => {
                this.source?.close();

                if (this.listeners.onError) {
                    this.listeners.onError();
                }
            });

            this.source.addEventListener(
                "close",
                () => {
                    if (this.listeners.onClose) {
                        this.listeners.onClose();
                    }

                    if (this.reconnect) {
                        reconnect();
                    }
                },
                {
                    once: true,
                },
            );
        } catch {
            if (this.reconnect) {
                reconnect();
            }
        }
    }

    send(data) {
        try {
            this.source?.send(data);
        } catch {}
    }

    close() {
        this.reconnect = false;

        try {
            this.source?.close();
        } catch {}
    }
}

class AudioPlayer {
    constructor(url) {
        this.init(url);
    }

    init(url) {
        if (!ENABLE) {
            return;
        }

        this.player = new PCMPlayer();

        this.connection = new AudioWebSocket(url, {
            onOpen: () => {
                if (this.player) {
                    this.player.continue();
                }
            },
            onMessage: (data) => {
                if (this.player) {
                    this.player.feed(data);
                }
            },
            onClose: () => {
                if (this.player) {
                    this.player.pause();
                }
            },
        });
    }

    start() {
        if (this.connection) {
            this.connection.send("start");
        }
    }

    stop() {
        if (this.connection) {
            this.connection.send("stop");
        }
    }

    end() {
        if (this.connection) {
            this.connection.close();
        }

        if (this.player) {
            this.player.destroy();
        }
    }
}

export default AudioPlayer;
