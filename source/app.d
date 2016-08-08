import std.stdio;
import std.random;

import derelict.sdl2.sdl;
import derelict.sdl2.image;

void main()
{
    DerelictSDL2.load();
    DerelictSDL2Image.load();

    if (SDL_Init(SDL_INIT_EVERYTHING))
    {
        writeln("Unable to initialize SDL:\n\t", SDL_GetError());
    }

    int IMG_FLAGS = IMG_INIT_PNG;
    if (!(IMG_Init(IMG_FLAGS) & IMG_FLAGS))
    {
        writeln("Failed to initialize SDL_Image:\n\t", IMG_GetError());
    }

    SDL_Window* window;
    SDL_Renderer* renderer;

    const int WINDOW_WIDTH = 512;
    const int WINDOW_HEIGHT = 384;
    if (SDL_CreateWindowAndRenderer(
                WINDOW_WIDTH, WINDOW_HEIGHT,
                SDL_WINDOW_OPENGL,
                &window, &renderer
                ))
    {
        writeln("Unable to create window:\n\t", SDL_GetError());
    }

    SDL_SetWindowTitle(window, "Danoi");

    const int PLATE_HEIGHT = 32;
    const int SHORT = 64;
    const int MEDIUM_SHORT = 85;
    const int MEDIUM_LONG = 106;
    const int LONG = 128;

    const int COLUMN_WIDTH = WINDOW_WIDTH / 3;

    SDL_Rect rect = {0, 0, SHORT, PLATE_HEIGHT};
    SDL_Point[4] triangle;

    enum Plate
    {
        EMPTY = 0,
        FIRST = SHORT,
        SECOND = MEDIUM_SHORT,
        THIRD = MEDIUM_LONG,
        FOURTH = LONG
    }

    Plate[4][3] stacks;
    stacks[0] = [
        Plate.FOURTH, Plate.THIRD, Plate.SECOND, Plate.FIRST
    ];

    Plate heldPlate = Plate.EMPTY;

    int selectedStack = 1;

    bool victory = false;
    float victoryTimer = 0;

    float delta;
    uint minFrameTimeMs = 10;
    float minFrameTime = (cast(float)minFrameTimeMs)/1000.0f;
    ulong prevTime = SDL_GetPerformanceCounter();
    ulong nowTime = SDL_GetPerformanceCounter();
    double countsPerSecond = cast(double)SDL_GetPerformanceFrequency();

    bool running = true;
    SDL_Event event;
    while (running)
    {
        while (SDL_PollEvent(&event))
        {
            switch(event.type)
            {
                case SDL_QUIT:
                    running = false;
                    break;
                case SDL_KEYDOWN:
                    if (victory) break;

                    SDL_Keycode keycode = event.key.keysym.sym;
                    if ((keycode == SDLK_d || keycode == SDLK_RIGHT))
                    {
                        selectedStack++;
                        if (selectedStack > 2) selectedStack = 2;
                    }
                    else if ((keycode == SDLK_a || keycode == SDLK_LEFT))
                    {
                        selectedStack--;
                        if (selectedStack < 0) selectedStack = 0;
                    }
                    else if (keycode == SDLK_SPACE)
                    {
                        if (heldPlate == Plate.EMPTY)
                        {
                            for (int i=3; i>=0; --i)
                            {
                                if (stacks[selectedStack][i] != Plate.EMPTY)
                                {
                                    heldPlate = stacks[selectedStack][i];
                                    stacks[selectedStack][i] = Plate.EMPTY;
                                    break;
                                }
                            }
                        }
                        else
                        {
                            for (int i=3; i>=0; --i)
                            {
                                if (stacks[selectedStack][i] == Plate.EMPTY)
                                {
                                    if (i == 0 || (stacks[selectedStack][i-1] > heldPlate))
                                    {
                                        stacks[selectedStack][i] = heldPlate;
                                        heldPlate = Plate.EMPTY;

                                        // Check for victory
                                        if (i == 3 && selectedStack == 2)
                                        {
                                            victory = true;
                                        }
                                    }
                                }
                            }
                        }
                    }

                    break;
                default:
                    break;
            }
        }

        prevTime = nowTime;
        nowTime = SDL_GetPerformanceCounter();
        delta = (cast(double)(nowTime-prevTime))/countsPerSecond;

        if (delta < minFrameTime)
        {
            SDL_Delay(minFrameTimeMs-(cast(uint)(delta*1000.0f)));
            delta = minFrameTime;
        }

        // Render stuff
        SDL_SetRenderDrawColor(renderer, 0x2D, 0x2D, 0x2D, 0xFF);
        SDL_RenderClear(renderer);

        if (heldPlate != Plate.EMPTY)
        {
            bool ok = true;
            for (int i=3; i>=0; --i)
            {
                if (stacks[selectedStack][i] != Plate.EMPTY)
                {
                    if (heldPlate > stacks[selectedStack][i])
                    {
                        ok = false;
                    }
                    break;
                }
            }

            if (ok)
            {
                SDL_SetRenderDrawColor(renderer, 0x2D, 0xFA, 0x2D, 0xFF);
            }
            else
            {
                SDL_SetRenderDrawColor(renderer, 0xFA, 0x2D, 0x2D, 0xFF);
            }

            rect.x = selectedStack*COLUMN_WIDTH + COLUMN_WIDTH/2 - heldPlate/2;
            rect.y = 10;
            rect.w = heldPlate;
            SDL_RenderFillRect(renderer, &rect);
        }

        if (victory)
        {
            victoryTimer += delta;
            SDL_SetRenderDrawColor(renderer, 0x2D, 0xFA, 0x2D, 0xFF);

            if (victoryTimer > 2)
            {
                victory = false;
                victoryTimer = 0;

                stacks[0] = [
                    Plate.FOURTH, Plate.THIRD, Plate.SECOND, Plate.FIRST
                ];

                stacks[2] = [
                    Plate.EMPTY, Plate.EMPTY, Plate.EMPTY, Plate.EMPTY
                ];
            }
        }
        else
        {
            SDL_SetRenderDrawColor(renderer, 0xFA, 0xFA, 0xFA, 0xFF);
        }

        int trianglePos = selectedStack*COLUMN_WIDTH + COLUMN_WIDTH/2;
        PositionTriangle(trianglePos, WINDOW_HEIGHT-20, triangle);
        SDL_RenderDrawLines(renderer, triangle.ptr, 4);

        for (int i=0; i<stacks.length; ++i)
        {
            for (int j=0; j<stacks[i].length; ++j)
            {
                switch(stacks[i][j])
                {
                    case Plate.EMPTY:
                        break;
                    case Plate.FIRST:
                        rect.w = SHORT;
                        rect.x = i*COLUMN_WIDTH + COLUMN_WIDTH/2 - SHORT/2;
                        rect.y = WINDOW_HEIGHT/3 + (PLATE_HEIGHT+1)*(4 - j);
                        SDL_RenderFillRect(renderer, &rect);
                        break;
                    case Plate.SECOND:
                        rect.w = MEDIUM_SHORT;
                        rect.x = i*COLUMN_WIDTH + COLUMN_WIDTH/2 - MEDIUM_SHORT/2;
                        rect.y = WINDOW_HEIGHT/3 + (PLATE_HEIGHT+1)*(4 - j);
                        SDL_RenderFillRect(renderer, &rect);
                        break;
                    case Plate.THIRD:
                        rect.w = MEDIUM_LONG;
                        rect.x = i*COLUMN_WIDTH + COLUMN_WIDTH/2 - MEDIUM_LONG/2;
                        rect.y = WINDOW_HEIGHT/3 + (PLATE_HEIGHT+1)*(4 - j);
                        SDL_RenderFillRect(renderer, &rect);
                        break;
                    case Plate.FOURTH:
                        rect.w = LONG;
                        rect.x = i*COLUMN_WIDTH + COLUMN_WIDTH/2 - LONG/2;
                        rect.y = WINDOW_HEIGHT/3 + (PLATE_HEIGHT+1)*(4 - j);
                        SDL_RenderFillRect(renderer, &rect);
                        break;
                }
            }
        }

        SDL_RenderPresent(renderer);
    }

    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);

    IMG_Quit();
    SDL_Quit();
}

void PositionTriangle(int x, int y, ref SDL_Point[4] triangle)
{
    triangle[0].x = x;
    triangle[0].y = y-5;

    triangle[1].x = x+3;
    triangle[1].y = y+2;

    triangle[2].x = x-3;
    triangle[2].y = y+2;

    triangle[3].x = triangle[0].x;
    triangle[3].y = triangle[0].y;
}

