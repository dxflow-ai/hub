import React, {
    KeyboardEvent,
    useCallback,
    useEffect,
    useRef,
    useState,
} from "react";
import "./App.css";
import { ChatResponse, Message, Ollama } from "./ollama";
import {
    Bot,
    XIcon,
    SettingsIcon,
    CircleUserRound,
    Clipboard,
    CopyIcon,
    FileQuestionIcon,
    MoonIcon,
    ForwardIcon,
    StopCircleIcon,
    SunIcon,
    SunMoonIcon,
    Trash2Icon,
    Loader2Icon,
} from "lucide-react";
import MarkdownRenderer from "./MarkdownRenderer.tsx";
import { Button } from "./rac/Button.tsx";
import { Label } from "./rac/Field.tsx";
import { Select, SelectItem } from "./rac/Select.tsx";
import { ToggleButton } from "./rac/ToggleButton.tsx";
import { Checkbox } from "./rac/Checkbox.tsx";
import { ImageGridList, ImageGridListItem } from "./rac/ImageGridList.tsx";
import { TextArea, useDragAndDrop } from "react-aria-components";
import copy from "clipboard-copy";
import { isFileDropItem } from "react-aria";
import useLocalStorageState from "./hooks.ts";
import { TextField } from "./rac/TextField.tsx";
import { sleep } from "./ollama/utils.ts";

const DEFAULT_MODEL = "smollm2:135m";
const DEFAULT_PROMPT = `You are a helpful AI assistant trained on a vast amount of human knowledge. Answer as concisely as possible.`;

interface ImageItem {
    id: number;
    url: string;
    name: string;
    blob?: Blob;
}

type Capability = "vision" | "text";

interface Model {
    id: string;
    name: string;
    capabilities: Capability[];
}

function App() {
    const query = new URLSearchParams(location.search);

    const [prompt, setPrompt] = useState(``);
    const [systemPrompt, setSystemPrompt] = useLocalStorageState(
        "systemPrompt",
        query.get("prompt") || DEFAULT_PROMPT,
    );
    const [systemPromptEnabled, setSystemPromptEnabled] = useLocalStorageState(
        "systemPromptEnabled",
        false,
    );
    const [response, setResponse] = useState("");
    const [models, setModels] = useState<Model[]>([]);
    const [model, setModel] = useLocalStorageState(
        "model",
        query.get("model") || DEFAULT_MODEL,
    );

    const [pullModel, setPullModel] = useState("");
    const [pullState, setPullState] = useState({
        status: "idle" as "idle" | "loading" | "error",
        label: "",
        progress: 0,
    });

    const [removeModel, setRemoveModel] = useState(false);

    const [messages, setMessages] = useLocalStorageState<
        (Message & {
            context?: Partial<ChatResponse & { images?: ImageItem[] }>;
        })[]
    >("messages", []);

    const [currentTheme, setCurrentTheme] = useState<"dark" | "light">();
    const [themePreference, setThemePreference] = useLocalStorageState<
        "dark" | "light" | "system"
    >("theme", "system");
    const [autoScroll, setAutoScroll] = useState(true);
    const [isPreparing, setIsPreparing] = useState(false);
    const [isGenerating, setIsGenerating] = useState(false);
    const [showSidePanel, setShowSidePanel] = useLocalStorageState(
        "showSidePanel",
        true,
    );

    const [images, setImages] = useState<ImageItem[]>([]);

    const [imageCache] = useState<Map<string, ImageItem>>(new Map());

    const stopGeneratingRef = useRef<boolean>(false);

    const chatAreaRef = useRef<HTMLDivElement>(null);
    const promptRef = useRef<HTMLTextAreaElement>(null);

    const ollama = useRef<Ollama>(new Ollama());

    const reloadModels = useCallback(async () => {
        setModels(
            (await ollama.current.list()).models.map(
                (m) =>
                    ({
                        id: m.digest,
                        name: m.name,
                        capabilities: m.details.families?.includes("clip")
                            ? ["text", "vision"]
                            : ["text"],
                    }) as Model,
            ),
        );
    }, [ollama]);

    useEffect(() => {
        stopGenerating();
        ollama.current = new Ollama();
        (async () => await reloadModels())();
    }, [reloadModels]);

    function getSystemThemePreference() {
        if (window.matchMedia("(prefers-color-scheme: dark)").matches) {
            return "dark";
        } else if (window.matchMedia("(prefers-color-scheme: light)").matches) {
            return "light";
        }
    }

    useEffect(() => {
        if (currentTheme) {
            document.body.classList.remove("dark", "light");
            document.body.classList.add(currentTheme);
        }
    }, [currentTheme]);

    useEffect(() => {
        if (themePreference === "system") {
            setCurrentTheme(getSystemThemePreference());
        } else {
            setCurrentTheme(themePreference);
        }
    }, [themePreference]);

    useEffect(() => {
        const dark = window.matchMedia("(prefers-color-scheme: dark)");
        const light = window.matchMedia("(prefers-color-scheme: dark)");

        const onThemeChange = () => {
            if (themePreference === "system") {
                setCurrentTheme(getSystemThemePreference());
            }
        };

        dark.addEventListener("change", onThemeChange);
        light.addEventListener("change", onThemeChange);

        return function cleanup() {
            dark.removeEventListener("change", onThemeChange);
            light.removeEventListener("change", onThemeChange);
        };
    }, [themePreference]);

    function toggleThemePreference() {
        if (themePreference === "system") {
            setThemePreference("light");
        } else if (themePreference === "light") {
            setThemePreference("dark");
        } else if (themePreference === "dark") {
            setThemePreference("system");
        }
    }

    useEffect(() => {
        if (autoScroll) {
            const intervalId = setInterval(() => {
                if (isGenerating) {
                    chatAreaRef.current?.scrollBy({
                        top: 250,
                        behavior: (window as any)["__TAURI__"]
                            ? "auto"
                            : "smooth",
                    });
                }
            }, 50);
            return () => clearInterval(intervalId);
        }
    }, [autoScroll, isGenerating]);

    async function pull() {
        if (pullState.status != "idle") {
            return;
        }

        setPullState({
            status: "loading",
            label: `Pulling ${pullModel}`,
            progress: 0,
        });

        await sleep(1000);

        try {
            const res = await ollama.current.pull({
                model: pullModel,
                stream: true,
            });

            for await (let part of res) {
                setPullState({
                    status: "loading",
                    label:
                        part.status.charAt(0).toUpperCase() +
                        part.status.slice(1),
                    progress: Math.round(
                        ((part?.completed ?? 0) * 100) / (part?.total ?? 100),
                    ),
                });
            }

            await reloadModels();

            setModel(pullModel);
        } catch (error) {
            console.error(error);

            setPullState({
                status: "error",
                label: "An error occurred",
                progress: 0,
            });

            await sleep(2500);
        }

        setPullModel("");
        setPullState({
            status: "idle",
            label: "",
            progress: 0,
        });
    }

    async function remove(name: string) {
        setRemoveModel(true);

        try {
            await ollama.current.delete({
                model: name,
            });

            await reloadModels();
        } catch (error) {
            console.error(error);
        }
    }

    const onWheel = (e: React.WheelEvent<HTMLElement>) => {
        const { current } = chatAreaRef;

        if (current) {
            const isScrollingUp = e.deltaY < 0;
            const isScrollingDown = e.deltaY > 0;

            if (isScrollingUp || e.deltaX !== 0) {
                setAutoScroll(false);
            } else if (
                isScrollingDown &&
                current.scrollHeight > current.clientHeight
            ) {
                const isNearBottom =
                    current.scrollTop + current.clientHeight >=
                    current.scrollHeight - 250;

                if (isNearBottom) {
                    setAutoScroll(true);
                }
            }
        }
    };

    async function fetchBlob(url: string) {
        return await (await fetch(url)).blob();
    }

    async function updateImageCache(images: ImageItem[]) {
        for (const img of images) {
            if (imageCache.has(img.url)) {
                continue;
            }

            const imgCopy = (await fetchBlob(img.url)).slice();
            imageCache.set(img.url, {
                ...img,
                blob: imgCopy,
                url: URL.createObjectURL(imgCopy),
            });
        }
    }

    const chat = async (message: string) => {
        setIsPreparing(true);

        if (hasCapability(model, "vision")) {
            await updateImageCache(images);

            setMessages((prev) => [
                ...prev,
                { role: "user", content: message, context: { images } },
            ]);
        } else {
            setMessages((prev) => [
                ...prev,
                { role: "user", content: message },
            ]);
        }

        stopGeneratingRef.current = false;
        setIsGenerating(true);
        setResponse(" ");
        setAutoScroll(true);

        const res = await ollama.current.chat({
            model,
            messages: [
                {
                    role: "system",
                    content: systemPromptEnabled ? systemPrompt : "",
                },
                ...messages,
                hasCapability(model, "vision")
                    ? {
                          role: "user",
                          content: message,
                          images: images.map((i) => i.url),
                      }
                    : {
                          role: "user",
                          content: message,
                      },
            ],
            stream: true,
            options: {
                temperature: 0,
            },
        });

        await sleep(750);

        setIsPreparing(false);

        let resp = "";

        let part;

        for await (part of res) {
            if (stopGeneratingRef.current) {
                setIsGenerating(false);
                break;
            }

            await sleep(25);

            resp += part.message.content;
            setResponse(resp);
        }

        let context: Partial<ChatResponse> = {};
        context = Object.assign({}, part);
        delete context.message;

        setResponse("");

        if (resp.trim()) {
            setMessages((prev) => [
                ...prev,
                {
                    role: "assistant",
                    content: resp,
                    context,
                },
            ]);
        }

        setIsGenerating(false);
    };

    const submit = async () => {
        if (prompt) {
            setPrompt("");
            await chat(prompt.trim());
        }
    };

    const handleKeyDownOnPrompt = async (e: KeyboardEvent) => {
        if (e.key === "Enter" && !e.shiftKey) {
            e.preventDefault();
            if (canSubmit()) {
                await submit();
            }
        }
    };

    const toggleSidePanel = useCallback(() => {
        setShowSidePanel(!showSidePanel);
    }, [showSidePanel, setShowSidePanel]);

    function canSubmit() {
        return !isGenerating && prompt && model && models.length;
    }

    function clearMessages() {
        setMessages([]);
        promptRef.current?.focus();
    }

    function showStopButton() {
        return isGenerating;
    }

    function stopGenerating() {
        stopGeneratingRef.current = true;
    }

    function hasCapability(model: string, c: Capability) {
        return models.find((m) => m.name === model)?.capabilities.includes(c);
    }

    async function copyMessageToClipboard(
        m: Message & { context?: Partial<ChatResponse> },
    ) {
        await copy(m.content);
    }

    async function copyAllMessagesToClipboard() {
        await copy(
            messages
                .map(
                    (m) =>
                        "##### " +
                        m.role.toUpperCase() +
                        ":\n\n" +
                        m.content +
                        "\n\n---",
                )
                .join("\n\n"),
        );
    }

    const { dragAndDropHooks } = useDragAndDrop({
        acceptedDragTypes: ["image/jpeg", "image/png"],
        async onRootDrop(e) {
            const images = await Promise.all(
                e.items.filter(isFileDropItem).map(async (item) => ({
                    id: Math.random(),
                    url: URL.createObjectURL(await item.getFile()),
                    name: item.name,
                })),
            );
            setImages(images);
        },
    });

    function removeImage(image: ImageItem) {
        setImages((prev) => prev.filter((i) => i.id != image.id));
    }

    return (
        <div className={currentTheme}>
            <div className="relative flex h-screen cursor-default bg-white font-sans text-gray-700 dark:bg-neutral-700 dark:text-white">
                <div className="absolute left-4 top-4 z-10 flex items-center gap-2 print:hidden">
                    <ToggleButton
                        onPressEnd={toggleSidePanel}
                        className="rounded-full border-none bg-neutral-100 p-1.5 text-neutral-500 transition-none hover:bg-neutral-600 :text-white dark:bg-neutral-600 dark:text-white dark:hover:bg-neutral-300 dark:hover:text-neutral-800"
                    >
                        {showSidePanel ? (
                            <XIcon size={14} />
                        ) : (
                            <SettingsIcon size={14} />
                        )}
                    </ToggleButton>
                </div>
                <div className="absolute right-4 top-4 z-10 flex items-center gap-2 print:hidden">
                    <ToggleButton
                        onChange={toggleThemePreference}
                        className="rounded-full border-none bg-neutral-100 p-1.5 text-neutral-500 transition-none hover:bg-neutral-600 hover:text-white dark:bg-neutral-600 dark:text-white dark:hover:bg-neutral-300 dark:hover:text-neutral-800"
                    >
                        {themePreference === "system" ? (
                            <SunMoonIcon size={14} />
                        ) : themePreference === "light" ? (
                            <SunIcon size={14} />
                        ) : (
                            <MoonIcon size={14} />
                        )}
                    </ToggleButton>
                </div>
                <div
                    className={`fixed w-full transform transition-all ${showSidePanel ? "translate-x-0" : "-translate-x-full"}`}
                >
                    <aside className="relative flex h-screen min-h-[100vh] w-[100vw] flex-col bg-neutral-200 p-6 py-2 dark:bg-neutral-800 sm:w-[320px]">
                        <h1 className="mx-auto mb-6 mt-12 flex select-none items-center gap-2 text-3xl">
                            <span className="shrink-0 overflow-hidden">
                                <img
                                    className="object-fil h-10 w-10"
                                    alt="logo"
                                    src="app-icon.png"
                                />
                            </span>
                            <span className="font-prose">Ollama</span>
                        </h1>
                        <div className="relative mt-4 flex select-none items-center">
                            <Label className="text-neutral-700">Model</Label>
                        </div>
                        <div className="relative w-full select-none">
                            <Select
                                selectedKey={model}
                                aria-label="select-model"
                                className="mt-2 flex-1"
                                placeholder="Select a model"
                                onSelectionChange={(s) => {
                                    if (!removeModel) {
                                        setModel("" + s);
                                    }
                                }}
                                extra={
                                    <div className="flex flex-col mb-1 px-1">
                                        <hr className="border-neutral-200 dark:border-neutral-950" />
                                        <div className="flex items-center gap-4 h-9 select-none mt-1 bg-neutral-100 dark:bg-neutral-950 rounded-lg text-sm text-gray-900 dark:text-neutral-100">
                                            {pullState.status == "idle" ? (
                                                <TextField
                                                    className="w-full px-1"
                                                    placeholder="Type & Enter to pull a model"
                                                    value={pullModel}
                                                    onChange={(value) => {
                                                        setPullModel(value);
                                                    }}
                                                    onKeyDown={(e) => {
                                                        if (e.key === "Enter") {
                                                            pull();
                                                        }
                                                    }}
                                                />
                                            ) : (
                                                <div className="flex w-full items-baseline justify-between gap-1 py-2 px-3">
                                                    <span>
                                                        {pullState.label}
                                                    </span>
                                                    {pullState.status ===
                                                        "loading" && (
                                                        <div className="flex items-center gap-2 h-4">
                                                            <small>
                                                                {pullState.progress
                                                                    ? `${pullState.progress}%`
                                                                    : "~"}
                                                            </small>
                                                            <Loader2Icon
                                                                className="animate-spin"
                                                                size={10}
                                                            />
                                                        </div>
                                                    )}
                                                </div>
                                            )}
                                        </div>
                                    </div>
                                }
                            >
                                {models.map((m) => (
                                    <SelectItem
                                        id={m.name}
                                        key={"model_" + m.id}
                                    >
                                        <div
                                            className="relative flex w-full"
                                            onPointerDown={() => {
                                                setRemoveModel(false);
                                            }}
                                        >
                                            <span>{m.name}</span>
                                            {m.name != model &&
                                                m.name != DEFAULT_MODEL && (
                                                    <div
                                                        className="absolute flex w-6 h-6 items-center justify-center -top-0.5 -right-9 p-0.5 rounded-full bg-black/10 dark:bg-white/20"
                                                        onPointerDown={(e) => {
                                                            e.stopPropagation();
                                                            remove(m.name);
                                                        }}
                                                    >
                                                        <Trash2Icon size={12} />
                                                    </div>
                                                )}
                                        </div>
                                    </SelectItem>
                                ))}
                            </Select>
                        </div>
                        <div className="relative mt-6 flex select-none items-center">
                            <Label className="text-neutral-700">
                                System Prompt
                            </Label>
                        </div>
                        <div className="relative w-full select-none">
                            <TextArea
                                id="system-prompt"
                                aria-label="system-prompt"
                                disabled={!systemPromptEnabled}
                                className="mt-2 h-32 w-full select-none rounded-xl border border-neutral-300 p-4 pr-8 text-[0.85rem] outline-none focus:border-neutral-400 disabled:resize-none disabled:text-neutral-300 dark:border-neutral-400/40 dark:bg-neutral-800 dark:text-neutral-300 dark:focus:border-neutral-500 disabled:dark:border-neutral-700/50 disabled:dark:text-neutral-500"
                                value={systemPrompt}
                                onChange={(e) =>
                                    setSystemPrompt(e.target.value)
                                }
                            />
                            <Checkbox
                                isSelected={systemPromptEnabled}
                                onChange={setSystemPromptEnabled}
                                className="absolute bottom-3 right-3 cursor-pointer"
                            />
                        </div>
                        {hasCapability(model, "vision") && (
                            <div className="mt-4">
                                <ImageGridList
                                    aria-label="Image drop list"
                                    items={images}
                                    dragAndDropHooks={dragAndDropHooks}
                                    renderEmptyState={() =>
                                        "This model supports vision. You can drop images here and ask questions about them."
                                    }
                                    className="max-h-[300px] select-none overflow-y-scroll rounded-xl border border-neutral-300 p-4 text-sm text-neutral-500"
                                >
                                    {(item) => (
                                        <ImageGridListItem
                                            id={item.url}
                                            key={item.id}
                                            textValue={item.name}
                                        >
                                            <div className="relative">
                                                <img
                                                    className="h-[105px] w-[105px] rounded object-cover"
                                                    src={item.url}
                                                    alt={item.name}
                                                />
                                                <Trash2Icon
                                                    size="18"
                                                    className="absolute right-1 top-1 z-10 cursor-pointer rounded bg-black/30 p-0.5 text-white hover:bg-black/70"
                                                    onClick={() =>
                                                        removeImage(item)
                                                    }
                                                />
                                            </div>
                                        </ImageGridListItem>
                                    )}
                                </ImageGridList>
                            </div>
                        )}
                        <div className="flex-1"></div>
                        <div className="mb-4 w-full select-none">
                            <div className="mt-4">
                                <Button
                                    variant="secondary"
                                    className="w-full gap-2 pt-3"
                                    onPressEnd={clearMessages}
                                    isDisabled={
                                        isGenerating || messages.length == 0
                                    }
                                >
                                    <div className="inline-flex items-center justify-center gap-2">
                                        <Trash2Icon
                                            className="m-auto"
                                            size="16"
                                        />
                                        Clear conversation
                                    </div>
                                </Button>
                            </div>
                        </div>
                    </aside>
                </div>
                <main
                    className={`min-h-[100vh] w-full pt-16 font-prose transition-all ${showSidePanel && "hidden sm:block pl-[320px]"}`}
                >
                    <div className="relative m-auto flex h-full flex-col">
                        <div
                            className="grid select-none grid-cols-[auto_minmax(0,1fr)] gap-x-6 gap-y-4 overflow-y-auto px-8"
                            ref={chatAreaRef}
                            onWheel={onWheel}
                        >
                            <div className="group relative h-10 w-10 select-none">
                                <Bot
                                    className="absolute rounded bg-purple-400 p-[4px] text-white dark:bg-yellow-400 dark:text-yellow-900"
                                    size="38"
                                />
                                {!!messages.length && (
                                    <CopyIcon
                                        className="absolute hidden cursor-pointer rounded bg-purple-400 p-[4px] text-white active:text-purple-700 group-hover:block dark:bg-yellow-400 dark:text-yellow-900 active:dark:text-black"
                                        size="38"
                                        onClick={() =>
                                            copyAllMessagesToClipboard()
                                        }
                                    />
                                )}
                            </div>
                            <div className="mt-[7px] flex select-none flex-col gap-2 pr-8 font-prose">
                                How may I help you?
                            </div>
                            {messages.map((m, i) => (
                                <>
                                    {
                                        {
                                            user: (
                                                <div className="group relative h-10 w-10 select-none">
                                                    <Clipboard
                                                        className="absolute cursor-pointer rounded bg-blue-400 p-[6px] text-white active:text-blue-700 dark:bg-orange-400 dark:text-orange-900 active:dark:text-black"
                                                        size="38"
                                                        key={"icn_clip_" + i}
                                                        onClick={() =>
                                                            copyMessageToClipboard(
                                                                m,
                                                            )
                                                        }
                                                    />
                                                    <CircleUserRound
                                                        className="absolute rounded bg-blue-400 p-[6px] text-white group-hover:hidden dark:bg-orange-400 dark:text-orange-900"
                                                        size="38"
                                                        key={"icn_" + i}
                                                    />
                                                </div>
                                            ),
                                            assistant: (
                                                <div className="group relative h-10 w-10 select-none">
                                                    <Clipboard
                                                        className="absolute cursor-pointer rounded bg-purple-400 p-[4px] text-white active:text-purple-700 dark:bg-yellow-400 dark:text-yellow-900 active:dark:text-black"
                                                        size="38"
                                                        key={"icn_clip" + i}
                                                        onClick={() =>
                                                            copyMessageToClipboard(
                                                                m,
                                                            )
                                                        }
                                                    />
                                                    <Bot
                                                        className="absolute rounded bg-purple-400 p-[4px] text-white group-hover:hidden dark:bg-yellow-400 dark:text-yellow-900"
                                                        size="38"
                                                        key={"icn" + i}
                                                    />
                                                </div>
                                            ),
                                        }[m.role]
                                    }
                                    <div
                                        className={`prose flex select-text flex-col gap-2 pr-8 ${m.role === "user" ? "-ml-3 mr-4 rounded-[0.4rem] bg-neutral-100 pl-3 dark:bg-neutral-600" : ""}`}
                                    >
                                        <MarkdownRenderer
                                            theme={currentTheme}
                                            content={m.content}
                                            key={"md" + i}
                                        />
                                        {!!m.context?.images?.length && (
                                            <div className="grid w-full grid-cols-2 gap-6 px-4 pb-6">
                                                {m.role === "user" &&
                                                    m.context.images.map(
                                                        (img) =>
                                                            imageCache.get(
                                                                img.url,
                                                            ) ? (
                                                                <div className="col-span-1">
                                                                    <img
                                                                        className="h-auto rounded object-cover"
                                                                        key={
                                                                            "img_" +
                                                                            img.id
                                                                        }
                                                                        alt={
                                                                            img.name
                                                                        }
                                                                        src={
                                                                            imageCache.get(
                                                                                img.url,
                                                                            )
                                                                                ?.url
                                                                        }
                                                                    />
                                                                </div>
                                                            ) : (
                                                                <div className="col-span-1 flex h-14 w-14 items-center justify-center rounded border-2 border-gray-200">
                                                                    <FileQuestionIcon
                                                                        size="24"
                                                                        className="text-gray-200"
                                                                    ></FileQuestionIcon>
                                                                </div>
                                                            ),
                                                    )}
                                            </div>
                                        )}
                                    </div>
                                </>
                            ))}
                            {response ? (
                                <>
                                    <Bot
                                        className="rounded bg-purple-400 p-[4px] text-white dark:bg-yellow-400 dark:text-yellow-900"
                                        size="38"
                                    />
                                    <div className="prose flex flex-col gap-2 pr-8">
                                        {isPreparing ? (
                                            <p
                                                style={{
                                                    animation:
                                                        "pulse 0.25s cubic-bezier(0.4, 0, 0.6, 1) infinite",
                                                }}
                                            >
                                                <span>▌</span>
                                            </p>
                                        ) : (
                                            <MarkdownRenderer
                                                theme={currentTheme}
                                                content={response + "▌"}
                                            />
                                        )}
                                    </div>
                                </>
                            ) : (
                                ""
                            )}
                        </div>
                        <div className="flex-1"></div>
                        <div className="px-[4vw] pb-3 pt-8 print:hidden">
                            <div className="flex w-full rounded-xl border border-neutral-200 p-2 bg-neutral-50 dark:border-neutral-900 has-[:focus]:border-neutral-400 dark:bg-neutral-800 dark:has-[:focus]:border-neutral-950">
                                <TextArea
                                    id="prompt"
                                    aria-label="prompt"
                                    className="w-full select-none resize-none bg-transparent p-2 font-sans text-[0.95rem] text-neutral-600 outline-none placeholder:text-neutral-400 dark:text-white"
                                    value={prompt}
                                    onChange={(e) => setPrompt(e.target.value)}
                                    onKeyDown={handleKeyDownOnPrompt}
                                    autoFocus
                                    ref={promptRef}
                                    placeholder="Your message here..."
                                />

                                {showStopButton() ? (
                                    <Button
                                        className="bg-black"
                                        onPress={() => stopGenerating()}
                                    >
                                        <StopCircleIcon
                                            className="p-0"
                                            size={18}
                                        />
                                    </Button>
                                ) : (
                                    <Button
                                        isDisabled={!canSubmit()}
                                        className="group bg-black disabled:opacity-15 disabled:dark:opacity-85 disabled:pointer-events-none"
                                        onPress={submit}
                                    >
                                        <ForwardIcon
                                            size={18}
                                            className="font-bold rotate-90 -scale-x-100 text-white group-disabled:text-neutral-400 group-disabled:dark:text-neutral-600"
                                        />
                                    </Button>
                                )}
                            </div>
                        </div>
                    </div>
                </main>
            </div>
        </div>
    );
}

export default App;
