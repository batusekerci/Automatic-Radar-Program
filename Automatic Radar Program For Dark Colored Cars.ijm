
fps = 30;
videoWidth = 936;
videoHeight = 528;
totalFrames = 1858;

roiX = 520;
roiY = 0;
roiWidth = 416;
roiHeight = 528;

minSpeed = 5;    
maxSpeed = 120;   
minDistance = 3;

staticThreshold = 5;
staticFrameCount = 5;
staticCheckRadius = 5;

startFrame = 450;
endFrame = 650;
frameStep = 5;
darkThreshold = 60;
minSize = 50;
maxSize = 5000;
minValidFrames = 3;

var calibrationPoints = newArray(
    455.574, 101.860, 2.578,
    417.704, 84.783, 2.578,
    377.382, 71.787, 2.578,
    314.175, 50.678, 2.578,
    266.224, 37.708, 2.578,
    225.902, 29.023, 2.578,
    203.017, 24.423, 2.578,
    156.974, 16.201, 2.578,
    129.457, 11.033, 2.578,
    80.416, 5.394, 2.578
);

macro "AutoRadar - Dark Vehicles Only" {
    print("\\Clear");
    
    videoID = getImageID();
    videoTitle = getTitle();
    
    print("Frames: " + startFrame + " to " + endFrame + " (step: " + frameStep + ")");
    print("Dark Threshold: " + darkThreshold);
    print("Particle size: " + minSize + "-" + maxSize + " px²");
    print("Min valid frames: " + minValidFrames);
    print("");
    runDarkVehicleAnalysis(videoID, startFrame, endFrame, frameStep, darkThreshold, minSize, maxSize);
}

function runDarkVehicleAnalysis(videoID, startFrame, endFrame, frameStep, threshold, minSize, maxSize) {
    vehicleCount = 0;
    run("Clear Results");
    
    prevX = newArray(0);
    prevY = newArray(0);
    prevFrame = newArray(0);
    prevID = newArray(0);
    nextVehicleID = 1;
    
    blacklistX = newArray(0);
    blacklistY = newArray(0);
    blacklistFrames = newArray(0);
    staticObjectFilterCount = 0;
    
    Table.create("Vehicle_Tracks");
    
    for (frame = startFrame; frame <= endFrame; frame += frameStep) {
        selectImage(videoID);
        setSlice(frame);
        
        run("Duplicate...", " ");
        originalID = getImageID();
        
        makeRectangle(roiX, roiY, roiWidth, roiHeight);
        run("Crop");
        run("8-bit");
        
        run("Duplicate...", " ");
        cleanID = getImageID();
        close(originalID);
        originalID = cleanID;
        
        selectImage(originalID);
        run("Duplicate...", " ");
        edgeID = getImageID();
        run("Find Edges");
        setThreshold(1, 255);
        run("Convert to Mask");
        
        selectImage(originalID);
        run("Duplicate...", " ");
        darkID = getImageID();
        setThreshold(0, threshold);
        run("Convert to Mask");
        
        imageCalculator("AND create", edgeID, darkID);
        combinedID = getImageID();
        
        close(edgeID);
        close(darkID);
        close(originalID);
        
        selectImage(combinedID);
        
        run("Despeckle");
        run("Despeckle");
        
        run("Dilate");
        run("Dilate");
        run("Dilate");
        run("Dilate");
        
        run("Fill Holes");
        
        run("Erode");
        run("Erode");
        
        run("Analyze Particles...", "size=" + minSize + "-" + maxSize + " show=Nothing display clear");
        nObjects = nResults;
        
        if (nObjects > 0) {
            currX = newArray(nObjects);
            currY = newArray(nObjects);
            
            for (i = 0; i < nObjects; i++) {
                currX[i] = getResult("X", i) + roiX;
                currY[i] = getResult("Y", i) + roiY;
            }
            
            filteredX = newArray(0);
            filteredY = newArray(0);
            
            for (i = 0; i < nObjects; i++) {
                if (currY[i] < 50) {
                    staticObjectFilterCount++;
                    continue;
                }
                
                isBlacklisted = false;
                
                for (b = 0; b < blacklistX.length; b++) {
                    dx = abs(currX[i] - blacklistX[b]);
                    dy = abs(currY[i] - blacklistY[b]);
                    
                    if (dx <= staticCheckRadius && dy <= staticCheckRadius) {
                        isBlacklisted = true;
                        break;
                    }
                }
                
                if (!isBlacklisted) {
                    filteredX = Array.concat(filteredX, currX[i]);
                    filteredY = Array.concat(filteredY, currY[i]);
                } else {
                    staticObjectFilterCount++;
                }
            }
            
            nObjects = filteredX.length;
            currX = filteredX;
            currY = filteredY;
            
            if (nObjects == 0) {
                close(combinedID);
                continue;
            }
            
            currID = newArray(nObjects);
            Array.fill(currID, -1);
            
            if (prevX.length > 0 && frame > startFrame) {
                frameGap = frame - prevFrame[0];
                maxMovement = 70 * frameGap;
                
                usedPrevIdx = newArray(prevX.length);
                Array.fill(usedPrevIdx, 0);
                
                for (i = 0; i < nObjects; i++) {
                    minDist = 999999;
                    matchedIdx = -1;
                    
                    for (j = 0; j < prevX.length; j++) {
                        if (usedPrevIdx[j] == 1) continue;
                        
                        dx = currX[i] - prevX[j];
                        dy = currY[i] - prevY[j];
                        dist = sqrt(dx*dx + dy*dy);
                        
                        if (dist < minDist && dist < maxMovement) {
                            minDist = dist;
                            matchedIdx = j;
                        }
                    }
                    
                    if (matchedIdx >= 0 && minDist < maxMovement) {
                        currID[i] = prevID[matchedIdx];
                        usedPrevIdx[matchedIdx] = 1;
                    } else {
                        currID[i] = nextVehicleID;
                        nextVehicleID++;
                    }
                }
            } else {
                for (i = 0; i < nObjects; i++) {
                    currID[i] = nextVehicleID;
                    nextVehicleID++;
                }
            }
            
            for (i = 0; i < nObjects; i++) {
                selectWindow("Vehicle_Tracks");
                row = vehicleCount;
                Table.set("Frame", row, frame);
                Table.set("Vehicle_ID", row, currID[i]);
                Table.set("X", row, currX[i]);
                Table.set("Y", row, currY[i]);
                
                speedCalculated = false;
                
                if (prevX.length > 0 && frame > startFrame) {
                    for (j = 0; j < prevX.length; j++) {
                        if (prevID[j] == currID[i]) {
                            dx = currX[i] - prevX[j];
                            dy = currY[i] - prevY[j];
                            pixelDist = sqrt(dx*dx + dy*dy);
                            
                            coeff1 = getCalibrationCoefficient(currY[i]);
                            coeff2 = getCalibrationCoefficient(prevY[j]);
                            avgCoeff = (coeff1 + coeff2) / 2;
                            
                            realDist = pixelDist * avgCoeff;
                            timeInterval = (frame - prevFrame[j]) / fps;
                            
                            if (timeInterval > 0) {
                                speed = (realDist / timeInterval) * 3.6;
                                
                                Table.set("Pixel_Distance", row, pixelDist);
                                Table.set("Real_Distance_m", row, realDist);
                                Table.set("Time_s", row, timeInterval);
                                Table.set("Speed_kmh", row, speed);
                                Table.set("Coeff_m_per_px", row, avgCoeff);
                                Table.set("Prev_Frame", row, prevFrame[j]);
                                
                                speedCalculated = true;
                                
                                if (speed >= minSpeed && speed <= maxSpeed && pixelDist >= minDistance) {
                                    Table.set("Valid", row, 1);
                                } else {
                                    Table.set("Valid", row, 0);
                                }
                            }
                            break;
                        }
                    }
                }
                
                if (!speedCalculated) {
                    Table.set("Valid", row, 0);
                }
                
                vehicleCount++;
            }
            
            Table.update("Vehicle_Tracks");
            
            if (prevX.length > 0) {
                for (i = 0; i < nObjects; i++) {
                    for (j = 0; j < prevX.length; j++) {
                        if (prevID[j] == currID[i]) {
                            dx = abs(currX[i] - prevX[j]);
                            dy = abs(currY[i] - prevY[j]);
                            movement = sqrt(dx*dx + dy*dy);
                            
                            if (movement <= staticThreshold) {
                                inBlacklist = false;
                                blacklistIdx = -1;
                                
                                for (b = 0; b < blacklistX.length; b++) {
                                    bx = abs(currX[i] - blacklistX[b]);
                                    by = abs(currY[i] - blacklistY[b]);
                                    
                                    if (bx <= staticCheckRadius && by <= staticCheckRadius) {
                                        inBlacklist = true;
                                        blacklistIdx = b;
                                        break;
                                    }
                                }
                                
                                if (inBlacklist) {
                                    blacklistFrames[blacklistIdx]++;
                                } else {
                                    blacklistX = Array.concat(blacklistX, currX[i]);
                                    blacklistY = Array.concat(blacklistY, currY[i]);
                                    blacklistFrames = Array.concat(blacklistFrames, 1);
                                }
                            }
                        }
                    }
                }
            }
            
            prevX = currX;
            prevY = currY;
            prevFrame = newArray(nObjects);
            Array.fill(prevFrame, frame);
            prevID = currID;
        }
        
        close(combinedID);
    }
    
    while (nImages > 1) {
        selectImage(nImages);
        if (getImageID() != videoID) {
            close();
        }
    }
    
    calculateSummaryStatistics();
}

function getCalibrationCoefficient(yCoord) {
    n = calibrationPoints.length / 3;
    
    bestIdx1 = 0;
    bestIdx2 = 1;
    minDiff1 = 999999;
    minDiff2 = 999999;
    
    for (i = 0; i < n; i++) {
        yCalib = calibrationPoints[i*3];
        diff = abs(yCoord - yCalib);
        
        if (diff < minDiff1) {
            minDiff2 = minDiff1;
            bestIdx2 = bestIdx1;
            minDiff1 = diff;
            bestIdx1 = i;
        } else if (diff < minDiff2) {
            minDiff2 = diff;
            bestIdx2 = i;
        }
    }
    
    y1 = calibrationPoints[bestIdx1*3];
    px1 = calibrationPoints[bestIdx1*3 + 1];
    m1 = calibrationPoints[bestIdx1*3 + 2];
    coeff1 = m1 / px1;
    
    y2 = calibrationPoints[bestIdx2*3];
    px2 = calibrationPoints[bestIdx2*3 + 1];
    m2 = calibrationPoints[bestIdx2*3 + 2];
    coeff2 = m2 / px2;
    
    if (abs(y1 - y2) < 0.1) {
        return coeff1;
    }
    
    t = (yCoord - y1) / (y2 - y1);
    coefficient = coeff1 + t * (coeff2 - coeff1);
    
    return coefficient;
}

function calculateSummaryStatistics() {
    print("\nSUMMARY STATISTICS");
    
    selectWindow("Vehicle_Tracks");
    nRows = Table.size;
    
    if (nRows == 0) {
        print("No valid detections found.");
        return;
    }
    
    vehicleIDs = newArray(0);
    
    for (i = 0; i < nRows; i++) {
        id = Table.get("Vehicle_ID", i);
        valid = Table.get("Valid", i);
        
        if (valid == 1) {
            found = false;
            for (j = 0; j < vehicleIDs.length; j++) {
                if (vehicleIDs[j] == id) {
                    found = true;
                    break;
                }
            }
            
            if (!found) {
                vehicleIDs = Array.concat(vehicleIDs, id);
            }
        }
    }
    
    print("Total unique vehicles tracked: " + vehicleIDs.length);
    print("");
    
    idFirstFrame = newArray(vehicleIDs.length);
    idLastFrame = newArray(vehicleIDs.length);
    idFirstX = newArray(vehicleIDs.length);
    idFirstY = newArray(vehicleIDs.length);
    idLastX = newArray(vehicleIDs.length);
    idLastY = newArray(vehicleIDs.length);
    idValidCount = newArray(vehicleIDs.length);
    
    for (i = 0; i < vehicleIDs.length; i++) {
        id = vehicleIDs[i];
        firstFrame = 999999;
        lastFrame = 0;
        validCount = 0;
        
        for (j = 0; j < nRows; j++) {
            if (Table.get("Vehicle_ID", j) == id) {
                frame = Table.get("Frame", j);
                
                if (frame < firstFrame) {
                    firstFrame = frame;
                    idFirstX[i] = Table.get("X", j);
                    idFirstY[i] = Table.get("Y", j);
                }
                if (frame > lastFrame) {
                    lastFrame = frame;
                    idLastX[i] = Table.get("X", j);
                    idLastY[i] = Table.get("Y", j);
                }
                
                if (Table.get("Valid", j) == 1) {
                    validCount++;
                }
            }
        }
        
        idFirstFrame[i] = firstFrame;
        idLastFrame[i] = lastFrame;
        idValidCount[i] = validCount;
    }
    
    mergeMap = newArray(vehicleIDs.length);
    for (i = 0; i < vehicleIDs.length; i++) {
        mergeMap[i] = vehicleIDs[i];
    }
    
    mergeCount = 0;
    
    for (i = 0; i < vehicleIDs.length; i++) {
        for (j = i + 1; j < vehicleIDs.length; j++) {
            frameGap = idFirstFrame[j] - idLastFrame[i];
            frameOverlap = !(idLastFrame[i] < idFirstFrame[j] || idLastFrame[j] < idFirstFrame[i]);
            
            totalFrameSpan = abs(idFirstFrame[i] - idFirstFrame[j]) + abs(idLastFrame[i] - idLastFrame[j]);
            if (totalFrameSpan > 30) continue;
            
            if (!frameOverlap && (frameGap < -3 || frameGap > 10)) continue;
            
            dx1 = idLastX[i] - idFirstX[j];
            dy1 = idLastY[i] - idFirstY[j];
            dist1 = sqrt(dx1*dx1 + dy1*dy1);
            
            dx2 = idFirstX[i] - idFirstX[j];
            dy2 = idFirstY[i] - idFirstY[j];
            dist2 = sqrt(dx2*dx2 + dy2*dy2);
            
            dx3 = idLastX[i] - idLastX[j];
            dy3 = idLastY[i] - idLastY[j];
            dist3 = sqrt(dx3*dx3 + dy3*dy3);
            
            spatialDist = dist1;
            if (dist2 < spatialDist) spatialDist = dist2;
            if (dist3 < spatialDist) spatialDist = dist3;
            
            if (spatialDist < 60) {
                mergeMap[j] = vehicleIDs[i];
                mergeCount++;
            }
        }
    }
    
    if (mergeCount > 0) {
        changed = true;
        iterations = 0;
        while (changed && iterations < 10) {
            changed = false;
            iterations++;
            
            for (i = 0; i < vehicleIDs.length; i++) {
                if (mergeMap[i] != vehicleIDs[i]) {
                    targetID = mergeMap[i];
                    
                    for (j = 0; j < vehicleIDs.length; j++) {
                        if (vehicleIDs[j] == targetID && mergeMap[j] != targetID) {
                            mergeMap[i] = mergeMap[j];
                            changed = true;
                            break;
                        }
                    }
                }
            }
        }
        
        for (i = 0; i < nRows; i++) {
            currentID = Table.get("Vehicle_ID", i);
            
            for (j = 0; j < vehicleIDs.length; j++) {
                if (vehicleIDs[j] == currentID) {
                    newID = mergeMap[j];
                    if (newID != currentID) {
                        Table.set("Vehicle_ID", i, newID);
                    }
                    break;
                }
            }
        }
        
        Table.update("Vehicle_Tracks");
        
        vehicleIDs = newArray(0);
        for (i = 0; i < nRows; i++) {
            id = Table.get("Vehicle_ID", i);
            valid = Table.get("Valid", i);
            
            if (valid == 1) {
                found = false;
                for (j = 0; j < vehicleIDs.length; j++) {
                    if (vehicleIDs[j] == id) {
                        found = true;
                        break;
                    }
                }
                
                if (!found) {
                    vehicleIDs = Array.concat(vehicleIDs, id);
                }
            }
        }
        
    }
    
    validVehicleCount = 0;
    
    for (i = 0; i < vehicleIDs.length; i++) {
        id = vehicleIDs[i];
        
        sumSpeed = 0;
        sumDist = 0;
        sumTime = 0;
        count = 0;
        firstFrame = 999999;
        lastFrame = 0;
        
        allFirstX = 0; allFirstY = 0;
        allLastX = 0; allLastY = 0;
        allFirstFrame = 999999;
        allLastFrame = 0;
        
        for (j = 0; j < nRows; j++) {
            if (Table.get("Vehicle_ID", j) == id) {
                frame = Table.get("Frame", j);
                
                if (frame < allFirstFrame) {
                    allFirstFrame = frame;
                    allFirstX = Table.get("X", j);
                    allFirstY = Table.get("Y", j);
                }
                if (frame > allLastFrame) {
                    allLastFrame = frame;
                    allLastX = Table.get("X", j);
                    allLastY = Table.get("Y", j);
                }
                
                if (Table.get("Valid", j) == 1) {
                    speed = Table.get("Speed_kmh", j);
                    dist = Table.get("Real_Distance_m", j);
                    time = Table.get("Time_s", j);
                    
                    sumSpeed += speed;
                    sumDist += dist;
                    sumTime += time;
                    count++;
                    
                    if (frame < firstFrame) firstFrame = frame;
                    if (frame > lastFrame) lastFrame = frame;
                }
            }
        }
        
        if (count > 0) {
            if (sumTime > 0) {
                avgSpeed = (sumDist / sumTime) * 3.6;
            } else {
                avgSpeed = 0;
            }
            
            dx = allLastX - allFirstX;
            dy = allLastY - allFirstY;
            pathDistPx = sqrt(dx*dx + dy*dy);
            
            if (count >= minValidFrames && pathDistPx >= 50) {
                validVehicleCount++;
                print("Vehicle ID " + id + ": " + d2s(avgSpeed,1) + " km/h (avg) | " + 
                      d2s(sumDist,2) + "m in " + d2s(sumTime,2) + "s | " +
                      "Frames " + allFirstFrame + "-" + allLastFrame + " (" + count + " valid) | " +
                      "Path: (" + d2s(allFirstX,0) + "," + d2s(allFirstY,0) + ") → (" + d2s(allLastX,0) + "," + d2s(allLastY,0) + ") | " +
                      "Path dist: " + d2s(pathDistPx,1) + "px");
            }
        }
    }
    
    print("");
    print("TOTAL VALID VEHICLES: " + validVehicleCount + " (out of " + vehicleIDs.length + " tracked)");
}

