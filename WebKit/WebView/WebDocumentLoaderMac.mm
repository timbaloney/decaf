/*
 * Copyright (C) 2006 Apple Computer, Inc.  All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * 1.  Redistributions of source code must retain the above copyright
 *     notice, this list of conditions and the following disclaimer. 
 * 2.  Redistributions in binary form must reproduce the above copyright
 *     notice, this list of conditions and the following disclaimer in the
 *     documentation and/or other materials provided with the distribution. 
 * 3.  Neither the name of Apple Computer, Inc. ("Apple") nor the names of
 *     its contributors may be used to endorse or promote products derived
 *     from this software without specific prior written permission. 
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE AND ITS CONTRIBUTORS "AS IS" AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL APPLE OR ITS CONTRIBUTORS BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
    * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "WebDocumentLoaderMac.h"

#import <JavaScriptCore/Assertions.h>
#import <WebCore/SubstituteData.h>
#import <WebCore/FoundationExtras.h>

using namespace WebCore;

static HashSet<unsigned long>& loadingResources()
{
    static HashSet<unsigned long> resources;
    
    return resources;
}

WebDocumentLoaderMac::WebDocumentLoaderMac(const ResourceRequest& request, const SubstituteData& substituteData)
    : DocumentLoader(request, substituteData)
    , m_dataSource(nil)
    , m_hasEverBeenDetached(false)
    , m_loadCount(0)
{
}

void WebDocumentLoaderMac::setDataSource(WebDataSource *dataSource)
{
    ASSERT(!m_dataSource);
    HardRetain(dataSource);
    m_dataSource = dataSource;
}

WebDataSource *WebDocumentLoaderMac::dataSource() const
{
    return m_dataSource;
}

void WebDocumentLoaderMac::attachToFrame()
{
    DocumentLoader::attachToFrame();
    ASSERT(m_loadCount == 0);

    if (m_hasEverBeenDetached)
        HardRetain(m_dataSource);
}

void WebDocumentLoaderMac::detachFromFrame()
{
    DocumentLoader::detachFromFrame();
  
    m_hasEverBeenDetached = true;
    HardRelease(m_dataSource);
}

void WebDocumentLoaderMac::increaseLoadCount(unsigned long identifier)
{
    ASSERT(m_dataSource);
    
    if (loadingResources().contains(identifier))
        return;
    
    loadingResources().add(identifier);
       
    if (m_loadCount == 0)
        HardRetain(m_dataSource);
    
    m_loadCount++;
}

void WebDocumentLoaderMac::decreaseLoadCount(unsigned long identifier)
{
    ASSERT(m_loadCount > 0);

    loadingResources().remove(identifier);
    
    m_loadCount--;

    if (m_loadCount == 0)
        HardRelease(m_dataSource);
}
