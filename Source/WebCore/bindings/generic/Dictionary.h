/*
 * Copyright (C) 2010 Google Inc. All rights reserved.
 * Copyright (C) 2012 Apple Inc. All rights reserved.
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

#ifndef Dictionary_h
#define Dictionary_h

#include "JSDictionary.h"
#include "JSEventListener.h"
#include "NotImplemented.h"
#include "RBDictionary.h"
#include "ScriptType.h" 
#include "ScriptValue.h"
#include <wtf/HashMap.h>
#include <wtf/text/CString.h>
#include <wtf/text/WTFString.h>

namespace JSC {
class JSValue;
}

namespace WebCore {
class EventListener;

class Dictionary {
public:
    Dictionary();
    Dictionary(JSC::ExecState*, JSC::JSValue);
    Dictionary(VALUE rubyHash);

    // Returns true if a value was found for the provided property.
    template <typename Result>
    bool get(const char* propertyName, Result&) const;
    template <typename Result>
    bool get(const String& propertyName, Result&) const;
    
    template <typename T>
    PassRefPtr<EventListener> getEventListener(const char* propertyName, T* target) const;
    template <typename T>
    PassRefPtr<EventListener> getEventListener(const String& propertyName, T* target) const;

    bool isObject() const;
    bool isUndefinedOrNull() const;
    bool getOwnPropertiesAsStringHashMap(HashMap<String, String>&) const;
    bool getOwnPropertyNames(Vector<String>&) const;
    bool getWithUndefinedOrNullCheck(const String& propertyName, String& value) const;

private:
    template <typename T>
    JSC::JSObject* asJSObject(T*) const;
    
    // FIXME: Make this more generic.
    // It may be better for JSDictionary and RBDictionary to inherit a common
    // dictionary delegate class, then only store one here.
    JSDictionary m_dictionaryJS;
    RBDictionary m_dictionaryRB;
    ScriptType m_scriptType;
};

template <typename Result>
bool Dictionary::get(const char* propertyName, Result& result) const
{
    // FIXME: Make this more generic. 
    // Read the comment above at the declaration of the dictionary members.
    switch (m_scriptType) {
    case JSScriptType:
        if (!m_dictionaryJS.isValid())
            return false;
        return m_dictionaryJS.get(propertyName, result);
    case RBScriptType:
        if (!m_dictionaryRB.isValid())
            return false;
        return m_dictionaryRB.get(propertyName, result);
    }
    
}

template <typename Result>
bool Dictionary::get(const String& propertyName, Result& result) const
{
    return get(propertyName.utf8().data(), result);
}

template <typename T>
PassRefPtr<EventListener> Dictionary::getEventListener(const char* propertyName, T* target) const
{
    // FIXME: Implement this for RB as well.
    if (!m_dictionaryJS.isValid())
        return 0;

    ScriptValue eventListener;
    if (!m_dictionaryJS.tryGetProperty(propertyName, eventListener))
        return 0;
    if (eventListener.hasNoValue())
        return 0;
    if (!eventListener.isObject())
        return 0;

    return JSEventListener::create(asObject(eventListener.jsValue()), asJSObject(target), true, currentWorld(m_dictionaryJS.execState()));
}

template <typename T>
PassRefPtr<EventListener> Dictionary::getEventListener(const String& propertyName, T* target) const
{
    return getEventListener(propertyName.utf8().data(), target);
}

}

#endif // Dictionary_h
