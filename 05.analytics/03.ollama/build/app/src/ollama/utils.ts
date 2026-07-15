import type { Fetch, ErrorResponse } from "./interfaces.js";

class ResponseError extends Error {
    constructor(
        public error: string,
        public status_code: number,
    ) {
        super(error);
        this.name = "ResponseError";
    }
}

const checkOk = async (response: Response): Promise<void> => {
    if (!response.ok) {
        let message = `Error ${response.status}: ${response.statusText}`;
        let errorData: ErrorResponse | null = null;

        if (
            response.headers.get("content-type")?.includes("application/json")
        ) {
            try {
                errorData = (await response.json()) as ErrorResponse;
                message = errorData.error || message;
            } catch (error) {
                console.log("Failed to parse error response as JSON");
            }
        } else {
            try {
                console.log("Getting text from response");
                const textResponse = await response.text();
                message = textResponse || message;
            } catch (error) {
                console.log("Failed to get text from error response");
            }
        }

        throw new ResponseError(message, response.status);
    }
};

export const get = async (fetch: Fetch, host: string): Promise<Response> => {
    const response = await fetch(host);

    await checkOk(response);

    return response;
};

export const head = async (fetch: Fetch, host: string): Promise<Response> => {
    const response = await fetch(host, {
        method: "HEAD",
    });

    await checkOk(response);

    return response;
};

export const post = async (
    fetch: Fetch,
    host: string,
    data?: Record<string, unknown> | BodyInit,
): Promise<Response> => {
    const isRecord = (input: any): input is Record<string, unknown> => {
        return (
            input !== null && typeof input === "object" && !Array.isArray(input)
        );
    };

    const formattedData = isRecord(data) ? JSON.stringify(data) : data;

    const response = await fetch(host, {
        method: "POST",
        body: formattedData,
    });

    await checkOk(response);

    return response;
};

export const del = async (
    fetch: Fetch,
    host: string,
    data?: Record<string, unknown>,
): Promise<Response> => {
    const response = await fetch(host, {
        method: "DELETE",
        body: JSON.stringify(data),
    });

    await checkOk(response);

    return response;
};

export const parseJSON = async function* <T = unknown>(
    itr: ReadableStream<Uint8Array>,
): AsyncGenerator<T> {
    const decoder = new TextDecoder("utf-8");
    let buffer = "";

    const reader = itr.getReader();

    while (true) {
        const { done, value: chunk } = await reader.read();

        if (done) {
            break;
        }

        buffer += decoder.decode(chunk);

        const parts = buffer.split("\n");

        buffer = parts.pop() ?? "";

        for (const part of parts) {
            try {
                yield JSON.parse(part);
            } catch (error) {
                console.warn("invalid json: ", part);
            }
        }
    }

    for (const part of buffer.split("\n").filter((p) => p !== "")) {
        try {
            yield JSON.parse(part);
        } catch (error) {
            console.warn("invalid json: ", part);
        }
    }
};

export const sleep = async (ms: number): Promise<void> => {
    await new Promise((resolve) => setTimeout(resolve, ms));
};
