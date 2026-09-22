# IM_EventsReviewer

**Inspector Mike Events Reviewer** is an offline review and 
QC tool for subsea inspection event listings.

It brings inspection events, synchronised video, captured images 
and pipeline location information together in a single application, 
allowing an inspector to move quickly between an event listing 
and the supporting inspection media.

The application is intended particularly for reviewing anomaly 
and freespan records, but can also be used for general inspection 
event review.

## Features

### Event Review

- Load inspection event data from supported data sources
- Browse and filter inspection events
- Quickly show anomaly records
- Quickly show freespan records
- Display event details alongside the inspection media
- Navigate directly between records without manually locating the corresponding video
- Display the position and extent of events along the inspected pipeline
- Select events from the pipeline display and locate the corresponding record

### Synchronised Video

IM_EventsReviewer uses the Inspector Mike synchronised video framework 
to display video associated with the selected event.

Features include:

- Play up to four synchronised video channels simultaneously
- Automatically locate video containing the event timestamp
- Synchronous Play, Pause and Seek
- Automatic multi-channel layout
- Configurable channel ordering
- Configurable video grid layout
- Double-click a channel to maximise it
- Double-click again to return to the multi-channel view
- Middle mouse button to toggle Play/Pause
- Mouse wheel seeking
- Variable playback speed
- Frame/image capture

Video does not need to be reloaded unnecessarily when moving between 
nearby events contained within the currently loaded recordings.

### Images

Images associated with the current event are displayed alongside the video.

The image viewer supports:

- Multiple images per event
- Thumbnail browsing
- Opening an individual image for closer inspection
- Direct access to the underlying image file/folder

### Pipeline Event Display

The pipeline event display provides a graphical overview of events along 
the pipeline.

It can display point and ranged events such as:

- Anomalies
- Freespans
- Field joints and other pipeline features

The display provides an alternative way of navigating the inspection data 
and makes it easier to identify the relationship between nearby events.

### Filtering

The event listing can be filtered during review.

Built-in toolbar filters provide quick access to commonly reviewed records such as:

- Anomalies
- Freespans

The underlying dataset filtering also supports user-defined filtering 
where appropriate.

## Data Sources

IM_EventsReviewer separates the review interface from the source of the 
inspection data.

The current application supports two provider types.

### Starfix Database

IM_EventsReviewer can connect directly to a supported Starfix inspection 
database and retrieve event information for review.

This mode is intended for use where the original project database is available.

### Excel Event Listing

Inspection events can also be loaded from an Excel event listing for offline review.

Column mappings and other import settings are configurable to accommodate variations 
in exported and client-supplied event listings.

This allows the review tools to be used without requiring access to the original 
inspection database.

## Video Location

The application can associate an inspection event timestamp with the 
corresponding recorded video.

The shared Inspector Mike media libraries provide support for inspection video 
naming conventions and synchronised multi-channel playback.

Video handling is shared with other Inspector Mike applications including:

- IM_Video
- OptionsDVRWorkbench

## Typical Workflow

A typical review consists of:

1. Open a Starfix database or Excel event listing.
2. Configure or locate the associated inspection video and image folders.
3. Select an event from the event listing.
4. IM_EventsReviewer loads the corresponding synchronised video and event images.
5. Review the event against the recorded inspection media.
6. Move directly to the next event, select another event from the pipeline 
display, or apply a filter to concentrate on a particular class of record.

This allows inspection QC to be performed without repeatedly searching DVR 
folders and manually synchronising video timestamps with event listings.

## Development Status

IM_EventsReviewer is under active development.

It was originally developed to solve a practical offshore inspection review 
requirement and is being expanded as additional workflows and data sources 
are encountered.

The application architecture deliberately separates inspection data providers 
from the review interface so that additional database and event-listing 
formats can be supported without rewriting the review tools.

---

# Developer Information

## Build Information

IM_EventsReviewer is developed using Lazarus and Free Pascal.

It makes extensive use of the shared Inspector Mike libraries for:

- Dataset and application infrastructure
- Synchronised video playback
- Image viewing
- Application settings
- Messaging
- Common UI components

### Inspector Mike Common

Shared packages and source are maintained in the InspectorMike Common repository.

Repository:

https://github.com/mikecornflake/InspectorMike-common

## Video Playback

Video playback is based on **mpv** using the **UW_MPVPlayer** Free Pascal wrapper.

UW_MPVPlayer:

https://github.com/URUWorks/UW_MPVPlayer

mpv:

https://github.com/mpv-player/mpv

A suitable `libmpv-2.dll` must be available at runtime.

It may be placed:

- In a directory included in the system `PATH`
- Beside the IM_EventsReviewer executable
- In an `mpv\x86_64` subdirectory beneath the application directory

## Architecture

IM_EventsReviewer uses a provider-based architecture.

The review interface operates against a common data-provider interface rather 
than directly against a particular database or spreadsheet implementation.

Current providers include:

- Starfix database provider
- Excel Event Listing provider

This allows the same event grid, filtering, video synchronisation, 
image review and pipeline display components to operate against 
different inspection data sources.

Application components communicate through a lightweight message bus for 
operations such as:

- Timestamp changes
- KP changes
- Filter changes
- Data-provider state changes

The reusable media and UI components are maintained separately in the 
Inspector Mike common libraries.

## Licence

IM_EventsReviewer is released under the **GPL-3.0** licence.

You are free to use, distribute and modify the software subject to the 
terms of that licence.

Please keep the acknowledgements intact.

## Acknowledgements

Many thanks to the developers of:

- Lazarus
- Free Pascal
- mpv
- URUWorks UW_MPVPlayer

IM_EventsReviewer uses the mpv media engine for video playback and the 
UW_MPVPlayer Free Pascal wrapper.

## Who am I?

This project is developed by **Mike Thompson**, a CSWIP 3.4U Subsea Inspection Engineer 
and former professional Delphi developer who regularly works with offshore 
inspection video and inspection data from multiple contractors.

- Inspector Mike 2.0 Pty Ltd
- https://wiki.freepascal.org/User:Mike.cornflake
- https://github.com/mikecornflake
- mike.cornflake@gmail.com

## Why release this?

Inspection event review often requires moving repeatedly between an event 
listing, multiple video channels, captured images and other project data.

Commercial inspection packages do not always provide convenient tools 
for an end client or inspection team to perform this type of integrated 
offline review.

IM_EventsReviewer aims to make that process faster and simpler while 
remaining portable and suitable for real-world offshore inspection work.

## Is this free?

Yes.

Just keep the acknowledgements and comply with the GPL-3.0 licence.

## Can I modify it?

Yes.

Useful changes and additional data-provider support are welcome.