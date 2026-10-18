package com.aurunex.contact_card_builder
import org.junit.Assert.*
import org.junit.Test

class NdefCardProtocolTest {
 private fun bytes(vararg values:Int)=values.map{it.toByte()}.toByteArray()
 private fun selectApp(protocol:NdefCardProtocol)=protocol.process(bytes(0,0xA4,4,0,7,0xD2,0x76,0,0,0x85,1,1))
 private fun selectFile(protocol:NdefCardProtocol,id:Int)=protocol.process(bytes(0,0xA4,0,0x0C,2,0xE1,id))
 @Test fun contactRoundTripsInChunksWithoutInternet(){
  val data=ByteArray(700){(it%251).toByte()};val p=NdefCardProtocol(data)
  assertArrayEquals(bytes(0x90,0),selectApp(p));assertArrayEquals(bytes(0x90,0),selectFile(p,4))
  val first=p.process(bytes(0,0xB0,0,0,2));assertArrayEquals(bytes(2,188,0x90,0),first)
  val received=ArrayList<Byte>();var offset=2
  while(offset<data.size+2){val length=minOf(200,data.size+2-offset);val response=p.process(bytes(0,0xB0,offset shr 8,offset and 255,length));received.addAll(response.dropLast(2));offset+=length}
  assertArrayEquals(data,received.toByteArray())
 }
 @Test fun capabilityAndReadOnlyLimitsAreAdvertised(){val p=NdefCardProtocol(bytes(1,2,3));selectApp(p);selectFile(p,3);val cc=p.process(bytes(0,0xB0,0,0,15));assertEquals(0xFF,cc[14].toInt()and 255);assertArrayEquals(bytes(0x6D,0),p.process(bytes(0,0xD6,0,0,0)))}
 @Test fun malformedAndUnselectedCommandsDoNotExposeContact(){val p=NdefCardProtocol(bytes(1,2,3));assertArrayEquals(bytes(0x67,0),p.process(bytes(0,0xB0,0,0,3)));assertArrayEquals(bytes(0x67,0),p.process(bytes(0,0xA4,4,0,7)));selectApp(p);selectFile(p,4);assertArrayEquals(bytes(0x6B,0),p.process(bytes(0,0xB0,1,0,3)))}
}
